"""Session-mediated, read-only NATS notifications with bounded per-subject caches."""
import asyncio
from collections import deque
import re
import threading
import uuid

from event_delivery import connect_broker, decode_event

MAX_EVENTS = 64
MAX_ACCOUNTS = 16


class FeedError(ValueError):
    def __init__(self, status, message):
        super().__init__(message)
        self.status = status


class EventHub:
    """Trusted policy/cache. Session service is responsible for token verification."""
    def __init__(self, grants, accounts):
        self.lock = threading.RLock()
        self.accounts = frozenset(accounts)
        if not self.accounts or len(self.accounts) > MAX_ACCOUNTS or any(type(x) is not int or not 0 < x < 2**31 for x in self.accounts):
            raise ValueError('Explicit bounded account configuration required')
        if not grants or len(grants) > 100:
            raise ValueError('Explicit bounded subject policy required')
        self.online = {account: False for account in self.accounts}
        self.policy = {}
        self.cache = {}
        for subject, scope in grants.items():
            self.replace_grants(subject, scope)

    def _reset(self, subject):
        self.cache[subject] = {'epoch': uuid.uuid4().hex, 'seq': 0, 'events': deque(maxlen=MAX_EVENTS)}

    def replace_grants(self, subject, accounts):
        scope = frozenset(accounts)
        if not isinstance(subject, str) or not re.fullmatch(r'[A-Za-z0-9_.@-]{1,128}', subject) or any(type(x) is not int for x in scope) or not scope <= self.accounts:
            raise ValueError('Invalid server-owned broker scope')
        with self.lock:
            if subject not in self.policy and len(self.policy) >= 100:
                raise ValueError('Broker subject capacity reached')
            self.policy[subject] = (uuid.uuid4().hex, scope)
            self._reset(subject)

    def revoke(self, subject):
        with self.lock:
            self.policy.pop(subject, None)
            self.cache.pop(subject, None)

    def ready(self):
        with self.lock:
            return all(self.online.values())

    def connection(self, account, online):
        with self.lock:
            if account not in self.online or type(online) is not bool:
                raise ValueError('Unknown broker connection')
            if self.online[account] != online:
                self.online[account] = online
                for subject, (_, scope) in self.policy.items():
                    if account in scope:
                        self._reset(subject)

    def ingest(self, account, topic, raw):
        envelope = decode_event(topic, raw)
        if envelope['payload']['accountId'] != account or envelope['eventSequence'] >= 2**53:
            raise ValueError('Notification identity outside account or browser range')
        # Business payload values must never cross this notification boundary.
        event = {key: envelope[key] for key in ('eventId', 'executionId', 'eventSequence', 'eventKind')}
        event.update(topic=topic, accountId=account)
        with self.lock:
            if account not in self.online or not self.online[account]:
                return
            for subject, (_, scope) in self.policy.items():
                if account in scope:
                    cache = self.cache[subject]
                    cache['seq'] += 1
                    cache['events'].append((cache['seq'], event))

    def poll(self, subject, after=None, revision=None):
        if after is not None and (not isinstance(after, str) or not re.fullmatch(r'[0-9a-f]{32}:(0|[1-9][0-9]{0,15})', after)):
            raise FeedError(400, 'Invalid notification cursor')
        with self.lock:
            policy = self.policy.get(subject)
            if policy is None or (revision is not None and revision != policy[0]):
                raise FeedError(403, 'Notification scope revoked')
            version, scope = policy
            if any(not self.online[account] for account in scope):
                raise FeedError(503, 'Notification feed unavailable')
            cache = self.cache[subject]
            reset = after is None
            offset = 0
            if after is not None:
                epoch, text = after.split(':')
                offset = int(text)
                oldest = cache['events'][0][0] if cache['events'] else cache['seq'] + 1
                reset = epoch != cache['epoch'] or offset > cache['seq'] or offset < oldest - 1
            events = [] if reset else [dict(value) for sequence, value in cache['events'] if sequence > offset]
            return version, {'cursor': cache['epoch'] + ':' + str(cache['seq']), 'reset': reset, 'events': events}


class BrokerEvents(EventHub):
    """One verified TLS subscription identity per account; explicit reconnect/reset."""
    def __init__(self, grants, identities, endpoint, ca_file):
        super().__init__(grants, identities)
        self.identities = {}
        users = set()
        for account, value in identities.items():
            if not isinstance(value, dict) or set(value) != {'user', 'password'}:
                raise ValueError('Explicit account broker identity required')
            user, password = value['user'], value['password']
            if not isinstance(user, str) or not re.fullmatch(r'[a-z][a-z0-9_-]{0,40}', user) or user in users or not isinstance(password, str) or not 16 <= len(password) <= 1024:
                raise ValueError('Distinct scoped broker credentials required')
            users.add(user)
            self.identities[account] = dict(value)
        self.endpoint, self.ca_file = endpoint, ca_file
        self.stopping = threading.Event()
        self.thread = None

    async def _account(self, account, identity):
        delay = .25
        while not self.stopping.is_set():
            client = None
            errors = []
            try:
                client = await connect_broker(self.endpoint, identity['user'], identity['password'], self.ca_file, errors)
                async def receive(message):
                    try:self.ingest(account, message.subject, message.data)
                    except (ValueError, TypeError, KeyError):pass
                for kind in ('trades', 'positions'):
                    await client.subscribe(f'/accounts/{account}/{kind}', cb=receive,
                        pending_msgs_limit=MAX_EVENTS, pending_bytes_limit=MAX_EVENTS*8192)
                await client.flush(timeout=3)
                if errors:
                    raise ValueError('Broker subscription denied')
                self.connection(account, True)
                delay = .25
                while not self.stopping.is_set() and client.is_connected and not errors:
                    await asyncio.sleep(.1)
            except Exception:
                # Exceptions may contain credentials, server messages or subjects.
                # A failed account is exposed only as unavailable, never as ready.
                pass
            finally:
                self.connection(account, False)
                if client is not None:
                    try:
                        async with asyncio.timeout(3):await client.close()
                    except Exception:pass
            if not self.stopping.is_set():
                await asyncio.sleep(delay)
                delay = min(delay * 2, 5)

    async def _run(self):
        await asyncio.gather(*(self._account(account, identity) for account, identity in self.identities.items()))

    def start(self):
        if self.thread is not None:
            raise ValueError('Broker adapter already started')
        self.thread = threading.Thread(target=lambda: asyncio.run(self._run()), daemon=True)
        self.thread.start()
        return self

    def close(self):
        self.stopping.set()
        if self.thread is not None:
            self.thread.join(timeout=12)
            if self.thread.is_alive():
                raise RuntimeError('Broker adapter shutdown timed out')


def reader_permissions(account):
    if type(account) is not int or not 0 < account < 2**31:
        raise ValueError('Explicit account required')
    # An empty NATS allow list means unrestricted, not deny-all.
    return {'publish': {'deny': ['>']}, 'subscribe': {'allow': [f'/accounts/{account}/trades', f'/accounts/{account}/positions']}}
