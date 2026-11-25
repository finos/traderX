"""Bounded candidate adapters. No CLI, credential discovery or deployed-service cutover."""
import asyncio
import simplejson as json
import re
import ssl
from urllib.parse import urlsplit
import uuid

MAX_EVENT_BYTES = 8192
STREAM = 'SECURITY_EVENTS'
KINDS = {'trade.settled': ('trade', 'trades'), 'position.updated': ('position', 'positions')}


def validate_event(topic, value):
    if not isinstance(value, dict) or set(value) != {'eventId','eventSequence','executionId','eventKind','payload'}:
        raise ValueError('Invalid event envelope')
    kind = value['eventKind']
    if not isinstance(kind, str) or kind not in KINDS: raise ValueError('Invalid event kind')
    execution = str(uuid.UUID(value['executionId']))
    suffix, path = KINDS[kind]
    if value['eventId'] != execution+':'+suffix: raise ValueError('Invalid event identity')
    seq = value['eventSequence']
    if type(seq) is not int or not 0 < seq < 2**63: raise ValueError('Invalid sequence')
    payload = value['payload']
    if not isinstance(payload, dict) or type(payload.get('accountId')) is not int or payload['accountId'] <= 0:
        raise ValueError('Invalid account')
    if topic != f"/accounts/{payload['accountId']}/{path}": raise ValueError('Invalid event topic')
    encoded = json.dumps(value, separators=(',',':'), allow_nan=False).encode()
    if len(encoded) > MAX_EVENT_BYTES: raise ValueError('Event exceeds limit')
    return encoded


def decode_event(topic, raw):
    if len(raw) > MAX_EVENT_BYTES: raise ValueError('Event exceeds limit')
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result: raise ValueError('Duplicate JSON field')
            result[key] = value
        return result
    value = json.loads(raw, object_pairs_hook=pairs, use_decimal=True)
    validate_event(topic, value)
    return value


async def connect_broker(endpoint, user, password, ca_file, errors=None):
    import nats
    parsed = urlsplit(endpoint)
    if parsed.scheme != 'tls' or not parsed.hostname or parsed.username or parsed.password or parsed.path or parsed.query or parsed.fragment:
        raise ValueError('Explicit TLS broker endpoint required')
    if not re.fullmatch(r'[a-z][a-z0-9_-]{0,40}', user): raise ValueError('Invalid broker identity')
    context = ssl.create_default_context(cafile=str(ca_file))
    async def error_cb(error):
        # No server messages, subjects, credentials or payloads in diagnostics.
        if errors is not None and len(errors) < 16: errors.append(type(error).__name__)
    async with asyncio.timeout(5):
        return await nats.connect(endpoint, user=user, password=password, tls=context,
          tls_handshake_first=True, allow_reconnect=False, connect_timeout=3,
          error_cb=error_cb, inbox_prefix=('_INBOX.'+user).encode(),
          pending_size=65536, flusher_queue_size=32)


class Store:
    """Scoped async psycopg connection, one short committed transaction per operation."""
    def __init__(self, connection):
        if not connection.autocommit: raise ValueError('Autocommit connection required')
        self.connection = connection
        from psycopg.types.json import set_json_loads
        set_json_loads(lambda raw: json.loads(raw, use_decimal=True), connection)

    async def claim(self, worker, limit=8, lease=30):
        async with self.connection.transaction():
            cursor = await self.connection.execute('SELECT * FROM lab_execution.claim_events(%s,%s,%s)', (worker,limit,lease))
            names = [col.name for col in cursor.description]
            return [dict(zip(names,row)) for row in await cursor.fetchall()]

    async def acknowledge(self, event_id, worker, token):
        async with self.connection.transaction():
            cursor = await self.connection.execute('SELECT lab_execution.ack_event(%s,%s,%s)', (event_id,worker,token))
            return (await cursor.fetchone())[0]

    async def consume(self, topic, envelope):
        from psycopg.types.json import Jsonb
        async with self.connection.transaction():
            cursor = await self.connection.execute('SELECT lab_execution.consume_event(%s,%s)', (topic,Jsonb(envelope, dumps=json.dumps)))
            return (await cursor.fetchone())[0]


class Publisher:
    def __init__(self, store, jetstream, worker=None):
        self.store, self.jetstream = store, jetstream
        self.worker = worker or uuid.uuid4()
        self.metrics = {'attempted':0, 'broker_accepted':0, 'sql_acknowledged':0, 'broker_duplicates':0}

    async def deliver(self, row):
        envelope = {'eventId':row['event_id'],'eventSequence':row['event_sequence'],
          'executionId':str(row['execution_id']),'eventKind':row['event_kind'],'payload':row['payload']}
        raw = validate_event(row['topic'], envelope)
        self.metrics['attempted'] += 1
        async with asyncio.timeout(5):
            ack = await self.jetstream.publish(row['topic'], raw,
                headers={'Nats-Msg-Id':row['event_id'],'Nats-Expected-Stream':STREAM}, timeout=3)
        if ack.stream != STREAM or type(ack.seq) is not int or ack.seq <= 0:
            raise ValueError('Unexpected broker acknowledgment')
        self.metrics['broker_accepted'] += 1
        if ack.duplicate: self.metrics['broker_duplicates'] += 1
        # If this fails, the lease remains pending and a subsequent process replays it.
        done = await self.store.acknowledge(row['event_id'], self.worker, row['lease_token'])
        if done: self.metrics['sql_acknowledged'] += 1
        return done

    async def run_once(self):
        rows = await self.store.claim(self.worker)
        for row in rows: await self.deliver(row)
        return len(rows)


async def consume_message(store, message):
    envelope = decode_event(message.subject, message.data)
    result = await store.consume(message.subject, envelope)
    if result not in ('applied','duplicate','stale'): raise ValueError('Unexpected consumer result')
    # Store.consume has committed inbox + effect before any acknowledgment is sent.
    # SQL/validation failure deliberately leaves the message unacknowledged.
    async with asyncio.timeout(5): await message.ack_sync(timeout=3)
    return result
