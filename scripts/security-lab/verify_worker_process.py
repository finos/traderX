"""Real owned worker processes; synthetic SQL gates, actual kill/restart and effects."""
import argparse
import asyncio
from contextlib import asynccontextmanager
import hashlib
import json
import os
from pathlib import Path
import secrets
import signal
import sys
import tempfile
import uuid

import bootstrap_database
from event_delivery import STREAM, connect_broker
from jetstream_fixture import broker, SUBJECTS
from resource_operation import operation
from verify_bootstrap import database, require, fingerprint
from verify_execution_reservations import MIGRATION, SETTLEMENT
from verify_execution_events import EVENTS
from verify_event_delivery import CONSUMER

ROOT = Path(__file__).resolve().parents[2]
WORKER = ROOT / 'scripts/security-lab/delivery_worker.py'


async def until(probe, label, process=None, seconds=20):
    deadline = asyncio.get_running_loop().time() + seconds
    while True:
        if process is not None and process.returncode is not None:
            raise AssertionError(label + ': worker exited')
        value = probe()
        if hasattr(value, '__await__'):
            value = await value
        if value:
            return
        if asyncio.get_running_loop().time() >= deadline:
            raise AssertionError(label + ': timed out')
        await asyncio.sleep(.1)


@asynccontextmanager
async def child(private, config):
    path = private / (uuid.uuid4().hex + '.json')
    path.write_text(json.dumps(config)); path.chmod(0o600)
    log = private / (path.stem + '.log')
    env = {k: v for k, v in os.environ.items() if not k.startswith('PG')}
    with log.open('xb') as output:
        log.chmod(0o600)
        proc = await asyncio.create_subprocess_exec(sys.executable, str(WORKER), '--config', str(path),
            stdout=output, stderr=output, env=env)
        proc.lab_log = log
        try:
            yield proc
        finally:
            if proc.returncode is None:
                proc.terminate()
                try:
                    await asyncio.wait_for(proc.wait(), 8)
                except TimeoutError:
                    proc.kill()
                    await asyncio.wait_for(proc.wait(), 5)


async def end(proc, sig, expected):
    proc.send_signal(sig)
    code = await asyncio.wait_for(proc.wait(), 8)
    if code != expected:
        raise AssertionError('Unexpected worker shutdown result')


async def campaign(runtime):
    import psycopg
    from nats.js.api import StreamConfig, ConsumerConfig, StorageType, AckPolicy, DiscardPolicy
    reference = bootstrap_database.pinned_reference()
    image = next(x for x in reference['items'] if x['kind'] == 'Deployment' and x['metadata']['name'] == 'database')['spec']['template']['spec']['containers'][0]['image']
    identities = bootstrap_database.credentials(); checks = []
    def check(value, label):
        if not value: raise AssertionError(label)
        checks.append(label)
    with database(runtime, image, persistent=True, loopback=True) as (sql, password, _, port):
        def admin(query): return require(sql('traderx', password, query), 'Process fixture SQL failed')
        admin(bootstrap_database.render(reference, identities))
        for path in (MIGRATION, SETTLEMENT, EVENTS, CONSUMER): admin(path.read_text())
        passwords = {name: secrets.token_hex(24) for name in ('event_publisher', 'event_consumer_a')}
        for name, secret in passwords.items():
            group = 'lab_event_publisher' if name == 'event_publisher' else 'lab_event_consumer'
            admin(f"CREATE ROLE {name} LOGIN PASSWORD '{secret}' IN ROLE {group}; GRANT CONNECT ON DATABASE traderx TO {name};")
        admin("INSERT INTO lab_execution.consumer_accounts VALUES ('event_consumer_a',22214);")
        admin("INSERT INTO orderbook(orderid,accountid,security,side,quantity,remainingquantity,limitprice,status,createdat,updatedat,acceptedsubject,acceptedissuer,acceptedterms) VALUES ('worker-process',22214,'IBM','Buy',1,1,100,'NEW',now(),now(),'synthetic','https://identity.example.test','fixture');")
        execution = str(uuid.uuid4())
        for service, query in [('order-matcher', f"SELECT lab_execution.reserve('{execution}','worker-process',1,99);"), ('trade-processor', f"SELECT lab_execution.settle('{execution}');")]:
            identity = identities[service]
            require(sql(identity['username'], identity['password'], query), 'Process fixture settlement failed')
        before = fingerprint(sql, password)
        with broker(runtime) as fixture, tempfile.TemporaryDirectory(prefix='worker-private-', dir=runtime) as temp:
            private = Path(temp)
            nc = await connect_broker(fixture['endpoint'], 'bootstrap', fixture['passwords']['bootstrap'], fixture['ca'])
            gate = await psycopg.AsyncConnection.connect(host='127.0.0.1', port=port, dbname='traderx', user='traderx', password=password, autocommit=True, connect_timeout=3)
            try:
                js = nc.jetstream()
                await js.add_stream(config=StreamConfig(name=STREAM, subjects=SUBJECTS, storage=StorageType.FILE,
                    max_bytes=8388608, max_msgs=10000, max_age=86400, discard=DiscardPolicy.NEW,
                    duplicate_window=1.0, num_replicas=1, max_msg_size=8192))
                await js.add_consumer(STREAM, config=ConsumerConfig(durable_name='ACCOUNT_A',
                    filter_subjects=['/accounts/22214/trades', '/accounts/22214/positions'],
                    ack_policy=AckPolicy.EXPLICIT, ack_wait=1.0, max_ack_pending=32, max_deliver=-1))
                base = dict(broker_endpoint=fixture['endpoint'], broker_ca=str(fixture['ca']),
                    database_host='127.0.0.1', database_port=port, database_name='traderx',
                    database_transport='fixture-loopback', database_ca=None, batch_size=1,
                    lease_seconds=2, poll_seconds=.1, operation_timeout_seconds=10,
                    retry_attempts=10, retry_base_seconds=.1, retry_cap_seconds=1, shutdown_seconds=3)
                def config(mode, broker_user, db_user):
                    return dict(base, mode=mode, broker_user=broker_user,
                        broker_password=fixture['passwords'][broker_user], database_user=db_user,
                        database_password=passwords[db_user])
                pub = config('publisher', 'publisher', 'event_publisher')
                con = dict(config('reference-consumer', 'consumer-a', 'event_consumer_a'), account_id=22214, durable='ACCOUNT_A')
                def blocked(role):
                    return admin(f"SELECT count(*) FROM pg_stat_activity WHERE usename='{role}' AND wait_event_type='Lock';") == '1'
                await gate.execute('SELECT pg_advisory_lock(41901)')
                admin("CREATE FUNCTION lab_execution.process_gate() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN PERFORM pg_advisory_xact_lock(41901); RETURN NEW; END $$; CREATE TRIGGER process_gate BEFORE UPDATE OF delivered_at ON lab_execution.events FOR EACH ROW EXECUTE FUNCTION lab_execution.process_gate();")
                async with child(private, pub) as p:
                    await until(lambda: blocked('event_publisher'), 'publisher acknowledgment gate', p)
                    check((await js.stream_info(STREAM)).state.messages == 1, 'broker accepted before publisher process kill')
                    await end(p, signal.SIGKILL, -signal.SIGKILL)
                check(admin('SELECT count(*) FROM lab_execution.events WHERE delivered_at IS NOT NULL;') == '0', 'killed publisher did not commit SQL acknowledgment')
                await gate.execute('SELECT pg_advisory_unlock(41901)')
                admin('DROP TRIGGER process_gate ON lab_execution.events; DROP FUNCTION lab_execution.process_gate();')
                await asyncio.sleep(2.2)
                async with child(private, pub) as p:
                    await until(lambda: admin('SELECT count(*) FROM lab_execution.events WHERE delivered_at IS NOT NULL;') == '2', 'publisher restart delivery', p)
                    check((await js.stream_info(STREAM)).state.messages == 3, 'replacement process replays after broker duplicate window')
                    await end(p, signal.SIGTERM, 0)
                    checks.append('publisher exits cleanly on actual SIGTERM')
                await gate.execute('SELECT pg_advisory_lock(41902)')
                admin("CREATE FUNCTION lab_execution.process_gate() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN PERFORM pg_advisory_xact_lock(41902); RETURN NEW; END $$; CREATE TRIGGER process_gate BEFORE INSERT ON lab_execution.trade_projection FOR EACH ROW EXECUTE FUNCTION lab_execution.process_gate();")
                async with child(private, con) as p:
                    await until(lambda: blocked('event_consumer_a'), 'consumer projection gate', p)
                    check((await js.consumer_info(STREAM, 'ACCOUNT_A')).num_ack_pending >= 1, 'consumer has unacknowledged delivery before kill')
                    await end(p, signal.SIGKILL, -signal.SIGKILL)
                check(admin('SELECT count(*) FROM lab_execution.consumer_inbox;') == '0', 'killed consumer rolls back inbox insertion')
                check(admin('SELECT count(*) FROM lab_execution.trade_projection;') == '0', 'killed consumer commits no partial trade projection')
                await gate.execute('SELECT pg_advisory_unlock(41902)')
                admin('DROP TRIGGER process_gate ON lab_execution.trade_projection; DROP FUNCTION lab_execution.process_gate();')
                async def consumed():
                    info = await js.consumer_info(STREAM, 'ACCOUNT_A')
                    return info.num_pending == 0 and info.num_ack_pending == 0 and admin('SELECT count(*) FROM lab_execution.consumer_inbox;') == '2'
                async with child(private, con) as p:
                    await until(consumed, 'consumer process recovery', p)
                    await end(p, signal.SIGTERM, 0)
                    checks.append('consumer drains durable replay and exits cleanly on actual SIGTERM')
                check(admin('SELECT count(*) FROM lab_execution.trade_projection;') == '1', 'duplicate broker messages produce one trade projection')
                check(admin('SELECT count(*) FROM lab_execution.position_projection;') == '1', 'one position projection survives process recovery')
                async with child(private, pub) as p, child(private, con) as c:
                    def running(proc):
                        return any(json.loads(line).get('status') == 'running' for line in proc.lab_log.read_text().splitlines() if line.startswith('{'))
                    await until(lambda: running(p), 'idle publisher readiness', p)
                    await until(lambda: running(c), 'idle consumer readiness', c)
                    checks.append('new worker processes report running after healthy idle polls')
                    await end(p, signal.SIGTERM, 0); await end(c, signal.SIGTERM, 0)
                check(admin('SELECT count(*) FROM lab_execution.consumer_inbox;') == '2' and (await js.stream_info(STREAM)).state.messages == 3, 'idle restart creates no additional messages or inbox effects')
                check(fingerprint(sql, password) == before, 'worker process failure and recovery never rebook business trades')
                logs = ''.join(path.read_text() for path in private.glob('*.log'))
                check(all(secret not in logs for secret in [*passwords.values(), *fixture['passwords'].values()]), 'actual worker logs contain no configured credentials')
                return {'status':'passed', 'scope':'actual CLI processes with synthetic SQL gates; no deployment acceptance',
                    'checks':checks, 'images':{'postgresql':image,'nats':fixture['image']},
                    'source_sha256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (WORKER, Path(__file__).resolve(), ROOT/'scripts/security-lab/event_delivery.py', MIGRATION, SETTLEMENT, EVENTS, CONSUMER)},
                    'limitations':['Synthetic transaction gates, actual SIGKILL/SIGTERM; not host power loss.', 'Same-database reference projection; browser and deployed identity acceptance separate.']}
            finally:
                await gate.close(); await nc.close()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-dir',type=Path,required=True); parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    if args.output.exists(): raise ValueError('Evidence already exists')
    with operation(args.runtime_dir,'fixture'): result=asyncio.run(campaign(args.runtime_dir))
    with args.output.open('x') as output: json.dump(result,output,indent=2); output.write('\n')
    print(f"Actual worker process recovery: {len(result['checks'])} checks passed; deployment acceptance remains pending.")


if __name__=='__main__': main()
