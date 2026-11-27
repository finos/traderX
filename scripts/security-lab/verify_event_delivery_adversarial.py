"""Independent local-only delivery boundary campaign; not deployed acceptance."""
import argparse
import asyncio
import copy
from decimal import Decimal
import hashlib
import importlib.metadata
import json
import platform
from pathlib import Path
import secrets
import subprocess
import uuid

import bootstrap_database
from event_delivery import Publisher, Store, STREAM, connect_broker, consume_message, validate_event
from jetstream_fixture import broker, SUBJECTS, LOCK as BROKER_LOCK
from resource_operation import operation
from verify_bootstrap import database, fingerprint, require
from verify_execution_reservations import MIGRATION, SETTLEMENT
from verify_execution_events import EVENTS
from verify_event_delivery import CONSUMER

ROOT = Path(__file__).resolve().parents[2]


def canonical_variants(envelope):
    """Valid wire shapes whose content differs from the authoritative outbox."""
    for label, field, value in (
        ('sequence', 'eventSequence', envelope['eventSequence'] + 100),
        ('execution identity', 'executionId', str(uuid.uuid4())),
        ('unexpected payload key', 'payload', dict(envelope['payload'], extra='unexpected')),
        ('decimal price', 'payload', dict(envelope['payload'], price=Decimal('900719925474099.124'))),
    ):
        changed = copy.deepcopy(envelope)
        changed[field] = value
        if field == 'executionId':
            changed['eventId'] = value + ':trade'
        yield label, changed


def wire_variants(raw):
    duplicate = raw.replace(b'"accountId":', b'"accountId":22214,"accountId":', 1)
    if duplicate == raw:
        raise ValueError('Expected canonical account field missing')
    return [
        ('duplicate payload key', duplicate, 'Duplicate JSON field'),
        ('unexpected envelope key', raw[:-1] + b',"unexpected":true}', 'Invalid event envelope'),
    ]


def expect(condition, label):
    if not condition:
        raise AssertionError(label)


async def expect_sql_denial(awaitable, label):
    import psycopg
    try:
        await awaitable
    except psycopg.Error as error:
        if error.sqlstate != '22023' or error.diag.message_primary != 'event unavailable':
            raise AssertionError(label + ': unexpected SQL denial') from None
    else:
        raise AssertionError(label + ': SQL accepted mutation')


class LostAck:
    def __init__(self, message):
        self.subject, self.data = message.subject, message.data

    async def ack_sync(self, **kwargs):
        raise LostAckError('injected after commit, before broker acknowledgment')


class LostAckError(Exception):
    pass


async def campaign(runtime):
    import psycopg
    from nats.js.api import StreamConfig, ConsumerConfig, StorageType, AckPolicy, DiscardPolicy

    reference = bootstrap_database.pinned_reference()
    image = next(d for d in reference['items'] if d['kind'] == 'Deployment' and d['metadata']['name'] == 'database')['spec']['template']['spec']['containers'][0]['image']
    identities = bootstrap_database.credentials()
    checks = []

    def check(value, label):
        expect(value, label)
        checks.append(label)

    with database(runtime, image, persistent=True, loopback=True) as (sql, password, _, port):
        def admin(statement):
            return require(sql('traderx', password, statement), 'Adversarial fixture SQL failed')

        def state():
            return admin("""SELECT json_build_object(
              'inbox',(SELECT json_agg(i ORDER BY login_role,event_id) FROM lab_execution.consumer_inbox i),
              'trades',(SELECT json_agg(t ORDER BY login_role,event_id) FROM lab_execution.trade_projection t),
              'positions',(SELECT json_agg(p ORDER BY login_role,account_id,security) FROM lab_execution.position_projection p))::text;""")

        admin(bootstrap_database.render(reference, identities))
        for path in (MIGRATION, SETTLEMENT, EVENTS, CONSUMER):
            admin(path.read_text())
        passwords = {role: secrets.token_hex(24) for role in ('event_publisher', 'event_consumer_a')}
        for role, secret in passwords.items():
            group = 'lab_event_publisher' if role == 'event_publisher' else 'lab_event_consumer'
            admin(f"CREATE ROLE {role} LOGIN PASSWORD '{secret}' IN ROLE {group}; GRANT CONNECT ON DATABASE traderx TO {role};")
        admin("INSERT INTO lab_execution.consumer_accounts VALUES ('event_consumer_a',22214);")
        admin("""INSERT INTO orderbook(orderid,accountid,security,side,quantity,remainingquantity,limitprice,status,createdat,updatedat,acceptedsubject,acceptedissuer,acceptedterms)
          VALUES ('delivery-adversarial',22214,'IBM','Buy',1,1,999999999999999.999,'NEW',now(),now(),'synthetic','https://identity.example.test','fixture');""")
        execution = str(uuid.uuid4())
        for service, statement in (
            ('order-matcher', f"SELECT lab_execution.reserve('{execution}','delivery-adversarial',1,900719925474099.123);"),
            ('trade-processor', f"SELECT lab_execution.settle('{execution}');"),
        ):
            identity = identities[service]
            require(sql(identity['username'], identity['password'], statement), 'Synthetic settlement failed')
        before_business = fingerprint(sql, password)
        connections, clients = [], []

        async def store(role):
            connection = await psycopg.AsyncConnection.connect(
                host='127.0.0.1', port=port, dbname='traderx', user=role,
                **{'password': passwords[role]}, autocommit=True,
                options='-c statement_timeout=3000 -c lock_timeout=3000')
            connections.append(connection)
            return Store(connection)

        with broker(runtime) as fixture:
            async def client(user):
                connection = await connect_broker(fixture['endpoint'], user, fixture['passwords'][user], fixture['ca'])
                clients.append(connection)
                return connection

            try:
                bootstrap = await client('bootstrap')
                js = bootstrap.jetstream()
                await js.add_stream(config=StreamConfig(name=STREAM, subjects=SUBJECTS, storage=StorageType.FILE,
                    max_bytes=8388608, max_msgs=10000, max_age=86400, discard=DiscardPolicy.NEW,
                    duplicate_window=1.0, num_replicas=1, max_msg_size=8192))
                await js.add_consumer(STREAM, config=ConsumerConfig(durable_name='ACCOUNT_A',
                    filter_subjects=['/accounts/22214/trades', '/accounts/22214/positions'],
                    ack_policy=AckPolicy.EXPLICIT, ack_wait=1.0, max_ack_pending=32, max_deliver=-1))
                pub = await client('publisher')
                consumer = await client('consumer-a')
                ps = await store('event_publisher')
                cs = await store('event_consumer_a')
                worker = uuid.uuid4()
                first = (await ps.claim(worker, 1, 1))[0]
                check(first['event_kind'] == 'trade.settled', 'claim selects synthetic trade')
                await asyncio.sleep(1.3)
                worker2 = uuid.uuid4()
                second = (await ps.claim(worker2, 1, 30))[0]
                check(first['event_id'] == second['event_id'] and first['lease_token'] != second['lease_token'], 'expired claim reissued with fresh token')
                check(not await ps.acknowledge(first['event_id'], worker, first['lease_token']), 'stale claimant cannot acknowledge replacement lease')
                check(admin("SELECT count(*) FROM lab_execution.events WHERE delivered_at IS NOT NULL;") == '0', 'stale acknowledgment leaves outbox pending')
                check(await Publisher(ps, pub.jetstream(), worker2).deliver(second), 'fresh lease publishes and acknowledges')
                check(admin("SELECT count(*) FROM lab_execution.events WHERE delivered_at IS NOT NULL;") == '1', 'fresh acknowledgment recorded in authoritative outbox')
                sub = await consumer.jetstream().pull_subscribe_bind(consumer='ACCOUNT_A', stream=STREAM,
                    pending_msgs_limit=32, pending_bytes_limit=65536)
                msg = (await sub.fetch(1, timeout=3))[0]
                from event_delivery import decode_event
                envelope = decode_event(msg.subject, msg.data)
                stable = state()
                for label, changed in canonical_variants(envelope):
                    validate_event(msg.subject, changed)
                    await expect_sql_denial(cs.consume(msg.subject, changed), label)
                    check(state() == stable, label + ' denied by canonical SQL without projection effects')
                check(fingerprint(sql, password) == before_business, 'tampering leaves trading state unchanged')
                try:
                    await consume_message(cs, LostAck(msg))
                except LostAckError:
                    pass
                else:
                    raise AssertionError('post-commit injected failure missing')
                committed = state()
                check(committed != stable and admin("SELECT count(*) FROM lab_execution.consumer_inbox;") == '1', 'injected ack loss follows committed inbox and projection')
                check(admin("SELECT (payload->>'price')::numeric=900719925474099.123 FROM lab_execution.trade_projection;") == 't', 'exact financial decimal persisted')
                await asyncio.sleep(1.3)
                retry = (await sub.fetch(1, timeout=3))[0]
                check(retry.data == msg.data and retry.metadata.num_delivered > 1, 'broker redelivers after injected acknowledgment loss')
                check(await consume_message(cs, retry) == 'duplicate' and state() == committed, 'redelivery neither duplicates nor changes projection')

                for label, raw, expected in wire_variants(msg.data):
                    await pub.jetstream().publish(msg.subject, raw, timeout=3)
                    invalid = (await sub.fetch(1, timeout=3))[0]
                    check(invalid.data == raw, label + ' reaches scoped consumer')
                    try:
                        await consume_message(cs, invalid)
                    except ValueError as error:
                        check(str(error) == expected, label + ' rejected at wire decoder')
                    else:
                        raise AssertionError(label + ': decoder accepted malformed event')
                    check(state() == committed and (await js.consumer_info(STREAM, 'ACCOUNT_A')).num_ack_pending == 1,
                          label + ' is unacknowledged and leaves projection unchanged')
                    await invalid.term()
                    await consumer.flush(timeout=3)

                changed = dict(envelope, eventSequence=envelope['eventSequence'] + 100)
                raw = validate_event(msg.subject, changed)
                await pub.jetstream().publish(msg.subject, raw, timeout=3)
                invalid = (await sub.fetch(1, timeout=3))[0]
                check(invalid.data == raw, 'canonical mismatch reaches scoped consumer')
                await expect_sql_denial(consume_message(cs, invalid), 'canonical mismatch through broker')
                check(state() == committed and (await js.consumer_info(STREAM, 'ACCOUNT_A')).num_ack_pending == 1,
                      'pre-commit SQL denial leaves message pending and projection unchanged')
                await invalid.term()
                await consumer.flush(timeout=3)
                check(fingerprint(sql, password) == before_business, 'delivery and retry leave trading state unchanged')
                return {
                    'status': 'passed', 'scope': 'local TLS broker and same-database reference consumer; not deployed acceptance',
                    'checks': checks, 'run_sha': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                    'platform': platform.platform(), 'python': platform.python_version(),
                    'images': {'postgresql': image, 'nats': fixture['image']},
                    'broker_architecture': fixture['architecture'],
                    'client_versions': {p: importlib.metadata.version(p) for p in ('nats-py', 'psycopg', 'psycopg-binary', 'simplejson')},
                    'source_sha256': {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in (
                        Path(__file__).resolve(), ROOT/'scripts/security-lab/event_delivery.py',
                        ROOT/'scripts/security-lab/jetstream_fixture.py', ROOT/'scripts/security-lab/verify_bootstrap.py',
                        ROOT/'scripts/security-lab/resource_operation.py', ROOT/'scripts/security-lab/resource_preflight.py',
                        ROOT/'scripts/security-lab/portability.py', ROOT/'scripts/security-lab/bootstrap_database.py',
                        ROOT/'scripts/security-lab/database_permissions.py', ROOT/'scripts/security-lab/prepare_runtime.py',
                        ROOT/'scripts/security-lab/lab.py',
                        ROOT/'scripts/security-lab/test_event_delivery_adversarial.py',
                        ROOT/'scripts/security-lab/requirements-delivery.txt', MIGRATION, SETTLEMENT, EVENTS, CONSUMER, BROKER_LOCK)},
                    'limits': {'postgresql_memory_mib': 256, 'broker_memory_mib': 128, 'loopback_ports': 2},
                    'limitations': ['Synthetic fault injection, not process or host failure.',
                        'Consumer validates against the same authoritative database, not independent signatures.',
                        'Publisher can withhold or falsely acknowledge claimed events; bootstrap remains trusted.',
                        'No application consumer, deployed environment or replicated availability tested.']}
            finally:
                for connection in clients:
                    await connection.close()
                for connection in connections:
                    await connection.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-dir', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        raise ValueError('Evidence already exists')
    with operation(args.runtime_dir, 'fixture'):
        result = asyncio.run(campaign(args.runtime_dir))
    with args.output.open('x') as output:
        json.dump(result, output, indent=2)
        output.write('\n')
    print(f"Independent delivery campaign: {len(result['checks'])} checks passed; deployed acceptance not claimed.")


if __name__ == '__main__':
    main()
