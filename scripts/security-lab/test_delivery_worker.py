import asyncio
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import AsyncMock, patch
import uuid

import nats.errors
from delivery_worker import ConfigurationError, TerminalError, Worker, load_config, supervise, terminal


class ConfigurationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / 'config.json'
        self.ca = Path(self.temp.name) / 'ca.pem'
        self.ca.write_text('fixture')
        self.config = dict(mode='publisher', broker_endpoint='tls://broker.example:4222',
                           broker_user='publisher', broker_password='private-broker-secret',
                           broker_ca=str(self.ca), database_host='127.0.0.1', database_port=5432,
                           database_name='traderx', database_user='publisher',
                           database_password='private-database-secret',
                           database_transport='fixture-loopback', database_ca=None,
                           batch_size=8, lease_seconds=30, poll_seconds=.1,
                           operation_timeout_seconds=1, retry_attempts=3, retry_base_seconds=.1,
                           retry_cap_seconds=1, shutdown_seconds=1)

    def write(self, config=None):
        self.path.write_text(json.dumps(config if config is not None else self.config))
        self.path.chmod(0o600)

    def test_private_and_transport_validation(self):
        self.write()
        self.assertEqual(load_config(self.path), self.config)
        for change in [
            {'database_host': 'localhost'}, {'database_host': '192.0.2.1'},
            {'database_transport': 'verify-full'}, {'database_port': True},
            {'broker_endpoint': 'tls://' + 'user' + '@broker.example:4222'},
            {'batch_size': 101}, {'poll_seconds': 0}, {'retry_base_seconds': 2},
            {'unknown': 'value'}, {'broker_password': ''},
        ]:
            with self.subTest(change=change):
                self.write(dict(self.config, **change))
                with self.assertRaises(ConfigurationError):
                    load_config(self.path)
        self.write(dict(self.config, database_host='db.example', database_transport='verify-full',
                        database_ca=str(self.ca)))
        load_config(self.path)
        self.path.chmod(0o640)
        with self.assertRaises(ConfigurationError):
            load_config(self.path)
        self.path.unlink()
        self.path.symlink_to(self.ca)
        with self.assertRaises(ConfigurationError):
            load_config(self.path)

    def test_duplicate_fields_and_libpq_environment_rejected(self):
        self.write()
        with patch.dict(os.environ, {'PGHOSTADDR': '192.0.2.1'}):
            with self.assertRaises(ConfigurationError):
                load_config(self.path)
        self.path.write_text('{"mode":"publisher","mode":"publisher"}')
        with self.assertRaises(ConfigurationError):
            load_config(self.path)

    def test_consumer_requires_explicit_scope(self):
        config = dict(self.config, mode='reference-consumer', account_id=22214, durable='ACCOUNT_A')
        self.write(config)
        load_config(self.path)
        for change in ({'account_id': True}, {'durable': 'ACCOUNT.*'}, {'account_id': 0}):
            self.write(dict(config, **change))
            with self.assertRaises(ConfigurationError):
                load_config(self.path)

    def test_cli_redacts_invalid_config(self):
        self.write(dict(self.config, database_host='private-database-secret'))
        result = subprocess.run([sys.executable, str(Path(__file__).with_name('delivery_worker.py')),
                                 '--config', str(self.path)], capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 2)
        self.assertEqual(json.loads(result.stdout)['status'], 'invalid_configuration')
        self.assertNotIn('private-', result.stdout + result.stderr)


class WorkerTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.stop = asyncio.Event()
        self.statuses = []
        self.config = dict(mode='publisher', batch_size=2, lease_seconds=30, poll_seconds=.1,
                           operation_timeout_seconds=1, retry_attempts=3, retry_base_seconds=1,
                           retry_cap_seconds=1.5, shutdown_seconds=1)
        self.worker = Worker(self.config, self.stop, self.statuses.append, jitter=lambda: 1)

    async def test_transient_backoff_reconnect_and_exhaustion_are_redacted(self):
        pauses = []
        async def pause(delay):
            pauses.append(delay)
        self.worker.pause = pause
        self.worker.connect = AsyncMock(side_effect=OSError('private-server-error'))
        self.assertEqual(await self.worker.run(), 1)
        self.assertEqual(pauses, [1, 1.5])
        self.assertEqual(self.worker.connect.await_count, 3)
        self.assertEqual(self.statuses[-1]['status'], 'exhausted')
        self.assertNotIn('private-server-error', json.dumps(self.statuses))

    async def test_terminal_authentication_does_not_retry(self):
        self.worker.connect = AsyncMock(side_effect=nats.errors.AuthorizationError())
        self.assertEqual(await self.worker.run(), 2)
        self.assertEqual(self.worker.connect.await_count, 1)
        self.assertTrue(terminal(OSError(), ['AuthorizationError']))
        self.assertTrue(terminal(nats.errors.Error('Authorization Violation'), []))
        self.assertTrue(terminal(nats.errors.SecureConnWantedError(), []))

    async def test_transient_reconnect_then_success_and_stop(self):
        connection = SimpleNamespace(close=AsyncMock())
        nc = SimpleNamespace(close=AsyncMock())
        self.worker.connect = AsyncMock(side_effect=[OSError(), (connection, nc)])
        self.worker.pause = AsyncMock()
        async def session(*args):
            self.stop.set()
            yield
        self.worker.session = session
        self.assertEqual(await self.worker.run(), 0)
        self.assertEqual(self.worker.connect.await_count, 2)
        connection.close.assert_awaited_once()
        nc.close.assert_awaited_once()
        self.assertEqual(self.statuses[-1]['counters']['reconnects'], 1)

    async def test_signal_shutdown_cancels_stalled_work_after_grace(self):
        handlers = {}
        loop = asyncio.get_running_loop()
        started = asyncio.Event()
        async def run():
            started.set()
            await asyncio.Event().wait()
        fake_worker = SimpleNamespace(run=run, status=lambda value: self.statuses.append(value))
        with patch('delivery_worker.Worker', return_value=fake_worker), \
             patch.object(loop, 'add_signal_handler', side_effect=lambda sig, callback: handlers.update({sig: callback})), \
             patch.object(loop, 'remove_signal_handler'):
            task = asyncio.create_task(supervise(self.config, self.statuses.append))
            await started.wait()
            handlers[next(iter(handlers))]()
            self.assertEqual(await asyncio.wait_for(task, 2), 1)
        self.assertEqual(self.statuses, ['shutdown_timeout'])

    async def test_stop_while_binding_consumer_is_orderly(self):
        self.config.update(mode='reference-consumer', account_id=22214, durable='ACCOUNT_A')
        async def bind(**kwargs):
            self.stop.set()
            return SimpleNamespace(fetch=AsyncMock())
        connection = SimpleNamespace(close=AsyncMock())
        js = SimpleNamespace(pull_subscribe_bind=AsyncMock(side_effect=bind))
        nc = SimpleNamespace(close=AsyncMock(), jetstream=lambda: js)
        self.worker.connect = AsyncMock(return_value=(connection, nc))
        with patch('delivery_worker.Store'):
            self.assertEqual(await self.worker.run(), 0)
        self.assertEqual(self.statuses[-1]['status'], 'stopped')
        self.assertEqual(self.worker.counts['failures'], 0)
        connection.close.assert_awaited_once()
        nc.close.assert_awaited_once()

    async def test_unexpected_session_end_is_terminal(self):
        connection = SimpleNamespace(close=AsyncMock())
        nc = SimpleNamespace(close=AsyncMock())
        self.worker.connect = AsyncMock(return_value=(connection, nc))
        async def empty(*args):
            if False:
                yield
        self.worker.session = empty
        self.assertEqual(await self.worker.run(), 2)
        self.assertEqual(self.statuses[-1]['status'], 'terminal')
        self.worker.connect.assert_awaited_once()

    async def test_stop_during_delivery_does_not_start_remaining_or_claim_again(self):
        store = SimpleNamespace(claim=AsyncMock(return_value=[1, 2]))
        publisher = SimpleNamespace(worker=uuid.uuid4(), metrics=dict(broker_accepted=0, sql_acknowledged=0))
        async def deliver(row):
            self.stop.set()
        publisher.deliver = AsyncMock(side_effect=deliver)
        nc = SimpleNamespace(jetstream=lambda: object())
        with patch('delivery_worker.Store', return_value=store), patch('delivery_worker.Publisher', return_value=publisher):
            session = self.worker.session(object(), nc, [])
            await anext(session)
            with self.assertRaises(StopAsyncIteration):
                await anext(session)
        publisher.deliver.assert_awaited_once_with(1)
        store.claim.assert_awaited_once()

    async def test_stop_during_claim_leaves_claimed_rows_unprocessed(self):
        async def claim(*args):
            self.stop.set()
            return [1]
        store = SimpleNamespace(claim=AsyncMock(side_effect=claim))
        publisher = SimpleNamespace(worker=uuid.uuid4(), deliver=AsyncMock())
        with patch('delivery_worker.Store', return_value=store), patch('delivery_worker.Publisher', return_value=publisher):
            session = self.worker.session(object(), SimpleNamespace(jetstream=lambda: object()), [])
            await anext(session)
            with self.assertRaises(StopAsyncIteration):
                await anext(session)
        store.claim.assert_awaited_once()
        publisher.deliver.assert_not_awaited()

    async def test_closed_broker_does_not_count_as_healthy_idle_poll(self):
        store = SimpleNamespace(claim=AsyncMock())
        nc = SimpleNamespace(jetstream=lambda: object(), is_closed=True)
        with patch('delivery_worker.Store', return_value=store), patch('delivery_worker.Publisher'):
            with self.assertRaises(OSError):
                await anext(self.worker.session(object(), nc, []))
        store.claim.assert_not_awaited()

    async def test_consumer_scope_rejects_foreign_subject_before_processing(self):
        self.config.update(mode='reference-consumer', account_id=22214, durable='ACCOUNT_A')
        message = SimpleNamespace(subject='/accounts/62654/trades')
        sub = SimpleNamespace(fetch=AsyncMock(return_value=[message]))
        js = SimpleNamespace(pull_subscribe_bind=AsyncMock(return_value=sub))
        nc = SimpleNamespace(jetstream=lambda: js)
        with patch('delivery_worker.Store'), patch('delivery_worker.consume_message', new_callable=AsyncMock) as consume:
            with self.assertRaises(TerminalError):
                await anext(self.worker.session(object(), nc, []))
            consume.assert_not_awaited()
        js.pull_subscribe_bind.assert_awaited_once_with(consumer='ACCOUNT_A', stream='SECURITY_EVENTS',
                                                         pending_msgs_limit=100, pending_bytes_limit=819200)

    async def test_consumer_processes_only_matching_subject(self):
        self.config.update(mode='reference-consumer', account_id=22214, durable='ACCOUNT_A')
        message = SimpleNamespace(subject='/accounts/22214/positions')
        sub = SimpleNamespace(fetch=AsyncMock(return_value=[message]))
        js = SimpleNamespace(pull_subscribe_bind=AsyncMock(return_value=sub))
        with patch('delivery_worker.Store'), patch('delivery_worker.consume_message', new_callable=AsyncMock) as consume:
            await anext(self.worker.session(object(), SimpleNamespace(jetstream=lambda: js), []))
            consume.assert_awaited_once()
        self.assertEqual(self.worker.counts['consumer_acknowledged'], 1)

    async def test_failed_acceptance_and_commit_never_acknowledged(self):
        from event_delivery import Publisher, consume_message
        execution = str(uuid.uuid4())
        row = dict(event_id=execution+':trade', event_sequence=1, execution_id=execution,
                   event_kind='trade.settled', payload={'accountId':22214},
                   topic='/accounts/22214/trades', lease_token=uuid.uuid4())
        store = SimpleNamespace(acknowledge=AsyncMock(), consume=AsyncMock(side_effect=OSError()))
        js = SimpleNamespace(publish=AsyncMock(side_effect=TimeoutError()))
        with self.assertRaises(TimeoutError):
            await Publisher(store, js).deliver(row)
        store.acknowledge.assert_not_awaited()
        envelope = dict(eventId=row['event_id'], eventSequence=1, executionId=execution,
                        eventKind='trade.settled', payload=row['payload'])
        msg = SimpleNamespace(subject=row['topic'], data=json.dumps(envelope).encode(), ack_sync=AsyncMock())
        with self.assertRaises(OSError):
            await consume_message(store, msg)
        msg.ack_sync.assert_not_awaited()


if __name__ == '__main__':
    unittest.main()
