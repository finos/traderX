#!/usr/bin/env python3
"""Supervised candidate publisher or account-scoped reference consumer."""
import argparse
import asyncio
import json
import math
import os
from pathlib import Path
import random
import re
import signal
import ssl
import stat
import sys
from urllib.parse import urlsplit

import nats.errors
import nats.js.errors
import psycopg

from event_delivery import Publisher, Store, STREAM, connect_broker, consume_message


class ConfigurationError(Exception):
    pass


class TerminalError(Exception):
    pass


def load_config(path):
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ConfigurationError()
            result[key] = value
        return result

    try:
        if not Path(path).is_absolute():
            raise ConfigurationError()
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        with os.fdopen(fd, 'rb') as source:
            info = os.fstat(source.fileno())
            if (not stat.S_ISREG(info.st_mode) or info.st_uid != os.geteuid()
                    or info.st_mode & 0o077 or info.st_size > 16384):
                raise ConfigurationError()
            config = json.loads(source.read(16385), object_pairs_hook=pairs)
        validate_config(config)
        return config
    except (OSError, ValueError, TypeError, UnicodeError, RecursionError):
        raise ConfigurationError() from None


def validate_config(c):
    common = {'mode', 'broker_endpoint', 'broker_user', 'broker_password', 'broker_ca',
              'database_host', 'database_port', 'database_name', 'database_user',
              'database_password', 'database_transport', 'database_ca', 'batch_size',
              'lease_seconds', 'poll_seconds', 'operation_timeout_seconds',
              'retry_attempts', 'retry_base_seconds', 'retry_cap_seconds', 'shutdown_seconds'}
    if not isinstance(c, dict) or c.get('mode') not in ('publisher', 'reference-consumer'):
        raise ConfigurationError()
    expected = common | ({'account_id', 'durable'} if c['mode'] == 'reference-consumer' else set())
    if set(c) != expected or any(key.startswith('PG') for key in os.environ):
        raise ConfigurationError()
    for key in ('broker_password', 'database_password'):
        if not isinstance(c[key], str) or not 1 <= len(c[key]) <= 1024 or any(ord(x) < 32 for x in c[key]):
            raise ConfigurationError()
    for key in ('database_name', 'database_user'):
        if not isinstance(c[key], str) or not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_-]{0,62}', c[key]):
            raise ConfigurationError()
    if not isinstance(c['broker_user'], str) or not re.fullmatch(r'[a-z][a-z0-9_-]{0,40}', c['broker_user']):
        raise ConfigurationError()
    host = c['database_host']
    if not isinstance(host, str) or not re.fullmatch(r'[A-Za-z0-9.:-]{1,253}', host):
        raise ConfigurationError()
    if not isinstance(c['broker_endpoint'], str):
        raise ConfigurationError()
    try:
        endpoint = urlsplit(c['broker_endpoint'])
        port = endpoint.port
        if (endpoint.scheme != 'tls' or not endpoint.hostname or endpoint.username or endpoint.password
                or endpoint.path or endpoint.query or endpoint.fragment or port is None or not 1 <= port <= 65535):
            raise ConfigurationError()
    except ValueError:
        raise ConfigurationError() from None
    if c['database_transport'] == 'fixture-loopback':
        if host not in ('127.0.0.1', '::1') or c['database_ca'] is not None:
            raise ConfigurationError()
    elif c['database_transport'] != 'verify-full':
        raise ConfigurationError()
    for key in ('broker_ca', 'database_ca'):
        if key == 'database_ca' and c['database_transport'] == 'fixture-loopback':
            continue
        if not isinstance(c[key], str) or not Path(c[key]).is_absolute() or not Path(c[key]).is_file():
            raise ConfigurationError()
    limits = {'database_port': (1, 65535), 'batch_size': (1, 100), 'lease_seconds': (1, 300),
              'retry_attempts': (1, 20)}
    if c['mode'] == 'reference-consumer':
        limits['account_id'] = (1, 2**63 - 1)
        if not isinstance(c['durable'], str) or not re.fullmatch(r'[A-Za-z0-9_-]{1,64}', c['durable']):
            raise ConfigurationError()
    for key, (low, high) in limits.items():
        if type(c[key]) is not int or not low <= c[key] <= high:
            raise ConfigurationError()
    for key, low, high in [('poll_seconds', .1, 60), ('operation_timeout_seconds', 1, 60),
                           ('retry_base_seconds', .1, 60), ('retry_cap_seconds', .1, 300),
                           ('shutdown_seconds', 1, 60)]:
        value = c[key]
        if type(value) not in (int, float) or not math.isfinite(value) or not low <= value <= high:
            raise ConfigurationError()
    if c['retry_base_seconds'] > c['retry_cap_seconds']:
        raise ConfigurationError()


def terminal(error, broker_errors):
    if any(name in ('AuthorizationError', 'AuthenticationExpiredError', 'InvalidUserCredentialsError',
                    'SSLCertVerificationError', 'Error') for name in broker_errors):
        return True
    if isinstance(error, (ConfigurationError, TerminalError, ValueError, ssl.SSLError,
                          nats.errors.AuthorizationError, nats.errors.AuthenticationExpiredError,
                          nats.errors.InvalidUserCredentialsError, nats.errors.SecureConnFailedError,
                          nats.errors.SecureConnRequiredError, nats.errors.SecureConnWantedError)):
        return True
    if isinstance(error, psycopg.Error):
        state = error.sqlstate or ''
        if state and not state.startswith(('08', '40', '53', '57')):
            return True
        if state:
            return False
        text = str(error).lower()
        return not any(word in text for word in ('connection refused', 'connection timed out',
                                                  'network is unreachable', 'no route to host',
                                                  'server closed the connection',
                                                  'temporary failure in name resolution'))
    if isinstance(error, nats.js.errors.APIError):
        return error.code not in (500, 503)
    if type(error) is nats.errors.Error:
        return True
    return not isinstance(error, (OSError, TimeoutError, nats.errors.Error))


class Worker:
    def __init__(self, config, stop, emit, jitter=random.random):
        self.config, self.stop, self.emit, self.jitter = config, stop, emit, jitter
        self.counts = dict(claimed=0, fetched=0, broker_accepted=0, sql_acknowledged=0,
                           consumer_acknowledged=0, failures=0, reconnects=0)

    def status(self, state):
        self.emit(dict(status=state, mode=self.config['mode'], counters=dict(self.counts)))

    async def pause(self, seconds):
        try:
            await asyncio.wait_for(self.stop.wait(), timeout=seconds)
        except TimeoutError:
            pass

    async def connect(self, errors):
        c = self.config
        kwargs = dict(host=c['database_host'], port=c['database_port'], dbname=c['database_name'],
                      user=c['database_user'], autocommit=True,
                      connect_timeout=5, gssencmode='disable',
                      options='-c statement_timeout=5000 -c lock_timeout=5000')
        kwargs['password'] = c['database_password']
        if c['database_transport'] == 'fixture-loopback':
            kwargs['sslmode'] = 'disable'
        else:
            kwargs.update(sslmode='verify-full', sslrootcert=c['database_ca'])
        connection = await psycopg.AsyncConnection.connect(**kwargs)
        try:
            nc = await connect_broker(c['broker_endpoint'], c['broker_user'], c['broker_password'],
                                      c['broker_ca'], errors)
        except BaseException:
            try:
                async with asyncio.timeout(2):
                    await connection.close()
            except Exception:
                pass
            raise
        return connection, nc

    async def session(self, connection, nc, errors):
        c = self.config
        store = Store(connection)
        js = nc.jetstream()
        def check_broker():
            if terminal(TimeoutError(), errors):
                raise TerminalError()
            if len(errors) >= 16 or getattr(nc, 'is_closed', False):
                raise OSError()
        if c['mode'] == 'publisher':
            publisher = Publisher(store, js)
        else:
            sub = await js.pull_subscribe_bind(consumer=c['durable'], stream=STREAM,
                                               pending_msgs_limit=100, pending_bytes_limit=819200)
        while not self.stop.is_set():
            check_broker()
            if c['mode'] == 'publisher':
                rows = await store.claim(publisher.worker, c['batch_size'], c['lease_seconds'])
                self.counts['claimed'] += len(rows)
                for row in rows:
                    if self.stop.is_set():
                        break
                    try:
                        await publisher.deliver(row)
                    finally:
                        self.counts['broker_accepted'] += publisher.metrics['broker_accepted']
                        self.counts['sql_acknowledged'] += publisher.metrics['sql_acknowledged']
                        publisher.metrics['broker_accepted'] = publisher.metrics['sql_acknowledged'] = 0
                if not rows:
                    await self.pause(c['poll_seconds'])
            else:
                try:
                    rows = await sub.fetch(c['batch_size'], timeout=c['poll_seconds'])
                except (TimeoutError, nats.errors.TimeoutError):
                    rows = []
                self.counts['fetched'] += len(rows)
                for message in rows:
                    if self.stop.is_set():
                        break
                    if message.subject not in (f"/accounts/{c['account_id']}/trades",
                                               f"/accounts/{c['account_id']}/positions"):
                        raise TerminalError()
                    await consume_message(store, message)
                    self.counts['consumer_acknowledged'] += 1
                if not rows:
                    await self.pause(c['poll_seconds'])
            check_broker()
            self.status('running')
            yield

    async def run(self):
        failures = 0
        self.status('starting')
        while not self.stop.is_set():
            errors = []
            connection = nc = None
            try:
                async with asyncio.timeout(self.config['operation_timeout_seconds']):
                    connection, nc = await self.connect(errors)
                session = self.session(connection, nc, errors)
                while not self.stop.is_set():
                    async with asyncio.timeout(self.config['operation_timeout_seconds'] + self.config['poll_seconds']):
                        await anext(session)
                    failures = 0
            except asyncio.CancelledError:
                raise
            except StopAsyncIteration:
                # A signal can arrive while the consumer binds its durable,
                # before the session yields its first batch.
                if self.stop.is_set():
                    self.status('stopped')
                    return 0
                self.counts['failures'] += 1
                self.status('terminal')
                return 2
            except Exception as error:
                self.counts['failures'] += 1
                if terminal(error, errors):
                    self.status('terminal')
                    return 2
                failures += 1
                if failures >= self.config['retry_attempts']:
                    self.status('exhausted')
                    return 1
                self.status('retrying')
            finally:
                for resource in (nc, connection):
                    if resource is not None:
                        try:
                            async with asyncio.timeout(2):
                                await resource.close()
                        except Exception:
                            pass
            if not self.stop.is_set():
                self.counts['reconnects'] += 1
                delay = min(self.config['retry_cap_seconds'],
                            self.config['retry_base_seconds'] * 2 ** (failures - 1))
                await self.pause(delay * (.5 + .5 * self.jitter()))
        self.status('stopped')
        return 0


async def supervise(config, emit):
    stop = asyncio.Event()
    loop = asyncio.get_running_loop()
    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, stop.set)
    worker = Worker(config, stop, emit)
    task = asyncio.create_task(worker.run())
    waiter = asyncio.create_task(stop.wait())
    try:
        done, _ = await asyncio.wait((task, waiter), return_when=asyncio.FIRST_COMPLETED)
        if task in done:
            return task.result()
        try:
            return await asyncio.wait_for(asyncio.shield(task), timeout=config['shutdown_seconds'])
        except TimeoutError:
            task.cancel()
            await asyncio.gather(task, return_exceptions=True)
            worker.status('shutdown_timeout')
            return 1
    finally:
        waiter.cancel()
        for sig in (signal.SIGTERM, signal.SIGINT):
            loop.remove_signal_handler(sig)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', required=True, help='absolute path to private JSON configuration')
    args = parser.parse_args()
    try:
        config = load_config(args.config)
    except ConfigurationError:
        print(json.dumps({'status': 'invalid_configuration'}), flush=True)
        return 2
    try:
        return asyncio.run(supervise(config, lambda value: print(json.dumps(value), flush=True)))
    except Exception:
        print(json.dumps({'status': 'terminal'}), flush=True)
        return 1


if __name__ == '__main__':
    sys.exit(main())
