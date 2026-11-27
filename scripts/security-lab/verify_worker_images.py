"""Hosted delivery/recovery campaign using the exact inspected worker OCI images."""
import argparse
import asyncio
from contextlib import asynccontextmanager, contextmanager
import copy
import hashlib
import json
import os
from pathlib import Path
import secrets
import subprocess
import tempfile
import uuid

import portability
import verify_runtime_images as images
from event_delivery import STREAM, connect_broker
from jetstream_fixture import SUBJECTS
from verify_bootstrap import fingerprint, require
from verify_execution_reservations import MIGRATION, SETTLEMENT
from verify_execution_events import EVENTS
from verify_event_delivery import CONSUMER
from verify_worker_process import until

ROOT = Path(__file__).resolve().parents[2]
NEGATIVES = ('database_password', 'broker_password', 'database_ca', 'broker_ca',
             'database_hostname', 'broker_hostname')
PHASES = frozenset(('configuration', 'images', 'fixture', 'bootstrap', 'negative_cases',
                   'publisher_gate', 'publisher_restart', 'consumer_precommit',
                   'consumer_postcommit_disable', 'consumer_postcommit_probe', 'consumer_postcommit_start',
                   'consumer_postcommit_window', 'consumer_postcommit_restore',
                   'consumer_restart', 'idle_restart', 'cleanup'))
PHASE = 'configuration'
DIAGNOSTIC = {}
FIXED_ERRORS = frozenset(('projection_ownership', 'worker_output_secret', 'worker_image_changed',
    'worker_not_running_at_signal', 'worker_signal_result', 'worker_oom_result', 'worker_cleanup_ownership',
    'hosted_linux_required', 'publisher_sql_session_verified_encrypted', 'broker_accepts_before_publisher_sql_ack',
    'killed_publisher_has_no_sql_ack', 'same_image_replays_after_broker_dedupe_window',
    'consumer_sql_session_verified_encrypted', 'consumer_precommit_has_unacked_delivery',
    'precommit_kill_rolls_back_inbox_and_projection', 'committed_effect_visible_while_ack_gate_holds_running_worker',
    'postcommit_kill_preserves_exactly_one_effect', 'consumer_same_image_recovery_deduplicates_committed_effect',
    'idle_same_image_restart_no_extra_delivery_effects', 'delivery_recovery_does_not_rebook_business_trade',
    'one_authoritative_settlement_receipt')) | frozenset(
        role + '_' + kind + '_' + suffix for role in ('event_publisher', 'event_consumer')
        for kind in NEGATIVES for suffix in ('terminal_rejection', 'no_effects'))
CHECK_IDS = FIXED_ERRORS | frozenset(('inspected_immutable_images_revalidated',
    'publisher_restricted_nonroot_private_materialization_verified',
    'consumer_restricted_nonroot_private_materialization_verified',
    'scoped_consumer_ack_permission_fault_confirmed_by_broker_probe',
    'scoped_consumer_ack_permission_restored_and_confirmed',
    'owned_workers_peers_network_and_private_files_cleaned'))


def phase(value):
    global PHASE
    if value not in PHASES:
        raise ValueError('Unknown campaign phase')
    PHASE = value


def checkpoint(checks, name):
    if not isinstance(name, str) or name not in CHECK_IDS:
        raise ValueError('Unknown fixed checkpoint')
    checks.append(name)
    print(json.dumps({'type': 'worker_image_checkpoint', 'check': name,
                      'result': 'passed', 'campaign_status': 'incomplete'}), flush=True)


class Failure(RuntimeError):
    pass


def failure(error):
    code = str(error) if isinstance(error, Failure) else ''
    value = {'status': 'failed', 'phase': PHASE,
             'error': code if code in FIXED_ERRORS else 'worker_image_campaign_failed'}
    if DIAGNOSTIC:
        value['worker'] = dict(DIAGNOSTIC)
    try:
        from worker_image_fixture import FixtureFailure
    except ImportError:
        FixtureFailure = ()
    if isinstance(error, FixtureFailure):
        value['peer'] = peer_diagnostic(error.details)
    return value


def peer_diagnostic(details):
    from worker_image_fixture import STAGES, ERROR_TYPES, PROBE_CODES
    details = details if isinstance(details, dict) else {}
    categories = ('unclassified', 'storage_capacity', 'readonly_filesystem', 'tls_private_key',
                  'permissions', 'authentication', 'tls_configuration', 'configuration', 'memory_limit')
    code = details.get('exit_code')
    stage, kind = details.get('stage'), details.get('error_type')
    probe = details.get('probe_code')
    return {'peer': details.get('peer') if details.get('peer') in ('database', 'broker') else 'unknown',
            'probe_code': probe if isinstance(probe,str) and probe in PROBE_CODES else None,
            'category': details.get('category') if details.get('category') in categories else 'unclassified',
            'running': details.get('running') if type(details.get('running')) is bool else None,
            'oom_killed': details.get('oom_killed') if type(details.get('oom_killed')) is bool else None,
            'exit_code': code if type(code) is int and 0 <= code <= 255 else None,
            'stage': stage if isinstance(stage, str) and stage in STAGES else 'guard',
            'error_type': kind if isinstance(kind, str) and kind in ERROR_TYPES else 'other'}


@asynccontextmanager
async def administration(fixture):
    """Close a connected broker even if the subsequent verified SQL connect fails."""
    import psycopg
    nc = gate = None
    try:
        nc = await connect_broker(fixture['broker']['host_endpoint'], 'bootstrap',
                                  fixture['broker']['passwords']['bootstrap'], fixture['broker']['ca'])
        gate = await psycopg.AsyncConnection.connect(host=fixture['database']['host'],
            hostaddr=fixture['database']['hostaddr'], port=5432, dbname='traderx', user='traderx',
            password=fixture['database_password'], autocommit=True, connect_timeout=3,
            sslmode='verify-full', sslrootcert=str(fixture['database']['ca']))
        yield nc, gate
    finally:
        try:
            if gate is not None:
                await gate.close()
        finally:
            if nc is not None:
                await nc.close()


def postcommit_visible(running, effects, initial, info, delivered, execution):
    """Correlate committed target effect and still-unacknowledged broker delivery."""
    return (running and effects == (1, 1, 0) and info.num_ack_pending >= 1 and
            info.ack_floor.consumer_seq == initial.ack_floor.consumer_seq and
            info.ack_floor.stream_seq == initial.ack_floor.stream_seq and
            info.delivered.stream_seq > info.ack_floor.stream_seq and
            json.loads(delivered.data)['eventId'] == execution + ':trade' and
            delivered.subject == '/accounts/22214/trades')


def worker_config(role, fixture, passwords):
    publisher = role == 'event-publisher'
    user = 'publisher' if publisher else 'consumer-a'
    dbuser = 'event_publisher' if publisher else 'event_consumer_a'
    value = dict(mode='publisher' if publisher else 'reference-consumer',
                 broker_endpoint=fixture['broker']['endpoint'], broker_user=user,
                 broker_password=fixture['broker']['passwords'][user],
                 broker_ca='/run/private/config/broker-ca.pem',
                 database_host=fixture['database']['host'], database_port=5432,
                 database_name='traderx', database_user=dbuser, database_password=passwords[dbuser],
                 database_transport='verify-full', database_ca='/run/private/config/database-ca.pem',
                 batch_size=1, lease_seconds=2, poll_seconds=.1, operation_timeout_seconds=10,
                 retry_attempts=10, retry_base_seconds=.1, retry_cap_seconds=1, shutdown_seconds=3)
    if not publisher:
        value.update(account_id=22214, durable='ACCOUNT_A')
    return value


def negative_config(config, kind, trusted, untrusted):
    """One intended connection-boundary change; all negative inputs remain valid."""
    if kind not in NEGATIVES:
        raise ValueError('Unknown negative case')
    changed = copy.deepcopy(config)
    values = dict(trusted)
    if kind.endswith('_password'):
        changed[kind] = secrets.token_hex(24)
    elif kind.endswith('_ca'):
        values[kind.replace('_', '-') + '.pem'] = untrusted
    elif kind == 'database_hostname':
        changed['database_host'] = 'wrong-database'
    else:
        changed['broker_endpoint'] = 'tls://wrong-broker:4222'
    return changed, values


def projection(root, name, config, values):
    target = root / name
    target.mkdir(mode=0o750)
    target.chmod(0o750)
    content = {'config.json': json.dumps(config).encode(), **values}
    if set(content) != {'config.json', 'broker-ca.pem', 'database-ca.pem'}:
        raise ValueError('Exact worker projection required')
    for key, value in content.items():
        path = target / key
        path.write_bytes(value)
        path.chmod(0o440)
    for command in (['sudo', '-n', 'chgrp', '10001', str(target)],
                    ['sudo', '-n', 'chown', '0:10001', *map(str, sorted(target.iterdir()))]):
        if subprocess.run(command, capture_output=True, timeout=10).returncode:
            raise Failure('projection_ownership')
    return target


def statuses(raw):
    """Parse only fixed runtime states; never return log text or untrusted fields."""
    found = []
    for line in raw.splitlines():
        try:
            value = json.loads(line)
        except (ValueError, TypeError):
            continue
        if isinstance(value, dict) and value.get('status') in (
                'starting', 'running', 'terminal', 'exhausted', 'retrying', 'stopped'):
            found.append(value['status'])
    return found


class WorkerImage:
    def __init__(self, fixture, verified, root, role, config, values, all_secrets):
        self.fixture, self.docker, self.role = fixture, fixture['docker'], role
        self.name = 'traderx-worker-' + secrets.token_hex(10)
        self.image = verified[role]['runtime_id']
        self.config_digest = verified[role]['config_digest']
        self.target = projection(root, self.name, config, values)
        self.all_secrets = all_secrets
        self.started = False

    def state(self):
        return json.loads(self.docker('inspect', self.name).stdout)[0]['State']

    def logs(self):
        result = self.docker('logs', '--tail', '100', self.name)
        raw = result.stdout + result.stderr
        if any(secret and secret in raw for secret in self.all_secrets):
            raise Failure('worker_output_secret')
        return statuses(raw)

    def running(self):
        return self.state().get('Running') is True

    def verify_restrictions(self):
        metadata = json.loads(self.docker('inspect', self.name).stdout)[0]
        self.verify_identity(metadata)
        probe = self.docker('exec', self.name, '/usr/local/bin/python', '-c', images.PRIVATE_PROBE)
        images.check_restrictions(metadata, json.loads(probe.stdout))

    def verify_identity(self, metadata):
        if metadata['Image'] not in (self.image, self.config_digest) or metadata['Config']['Image'] != self.image:
            raise Failure('worker_image_changed')

    def diagnose(self):
        state = self.state()
        DIAGNOSTIC.clear()
        DIAGNOSTIC.update(role=self.role, statuses=self.logs()[-8:],
                          running=state.get('Running') is True, oom_killed=state.get('OOMKilled') is True)
        code = state.get('ExitCode')
        if type(code) is int and 0 <= code <= 255:
            DIAGNOSTIC['exit_code'] = code

    def signal(self, signal, code):
        if not self.running():
            raise Failure('worker_not_running_at_signal')
        self.docker('kill', '--signal', signal, self.name)
        actual = self.docker('wait', self.name, timeout=10).stdout.strip()
        if actual != str(code):
            raise Failure('worker_signal_result')
        if self.state().get('OOMKilled') is not False:
            raise Failure('worker_oom_result')

    def cleanup(self):
        label = self.docker('inspect', '--format', '{{index .Config.Labels "' + images.LABEL + '"}}', self.name, check=False)
        if label.returncode:
            # A refused launch can leave no container. Confirm absence through a
            # second successful query; transport errors are never treated as absence.
            if 'No such' not in label.stderr:
                raise Failure('worker_cleanup_ownership')
            found = self.docker('ps', '-aq', '--filter', 'name=^/' + self.name + '$')
            if found.stdout.strip():
                raise Failure('worker_cleanup_ownership')
            return
        if label.stdout.strip() != self.fixture['owner']:
            raise Failure('worker_cleanup_ownership')
        try:
            self.logs()
        finally:
            self.docker('rm', '-f', self.name)

    @contextmanager
    def run(self):
        try:
            self.started = True
            self.docker(*images.launch_args(self.name, self.fixture['network'], self.fixture['owner'],
                                           self.target, self.image))
            self.verify_identity(json.loads(self.docker('inspect', self.name).stdout)[0])
            yield self
        except Exception:
            try:
                self.diagnose()
            except Exception:
                pass
            raise
        finally:
            if self.started:
                self.cleanup()


async def campaign(runtime, manifest):
    from nats.js.api import StreamConfig, ConsumerConfig, StorageType, AckPolicy, DiscardPolicy
    from worker_image_fixture import fixture
    if not portability.isolated_linux() or os.environ.get('GITHUB_ACTIONS') != 'true':
        raise Failure('hosted_linux_required')
    phase('images')
    verified = images.verified_images(manifest, images.Docker(runtime))
    checks = []
    checkpoint(checks, 'inspected_immutable_images_revalidated')

    def check(condition, name):
        if not condition:
            raise Failure(name)
        checkpoint(checks, name)

    phase('fixture')
    with fixture(runtime) as f, tempfile.TemporaryDirectory(prefix='worker-projections-', dir=runtime) as temp:
        root = Path(temp)
        admin, sql = f['admin'], f['sql']
        peer_images = {name: f[name]['image'] for name in ('database', 'broker')}
        phase('bootstrap')
        for path in (MIGRATION, SETTLEMENT, EVENTS, CONSUMER):
            admin(path.read_text())
        passwords = {name: secrets.token_hex(24) for name in ('event_publisher', 'event_consumer_a')}
        for name, password in passwords.items():
            group = 'lab_event_publisher' if name == 'event_publisher' else 'lab_event_consumer'
            admin(f"CREATE ROLE {name} LOGIN PASSWORD '{password}' IN ROLE {group}; GRANT CONNECT ON DATABASE traderx TO {name};")
        admin("INSERT INTO lab_execution.consumer_accounts VALUES ('event_consumer_a',22214);")
        admin("INSERT INTO orderbook(orderid,accountid,security,side,quantity,remainingquantity,limitprice,status,createdat,updatedat,acceptedsubject,acceptedissuer,acceptedterms) VALUES ('worker-image',22214,'IBM','Buy',1,1,100,'NEW',now(),now(),'synthetic','https://identity.example.test','fixture');")
        execution = str(uuid.uuid4())
        for role, query in [('order-matcher', f"SELECT lab_execution.reserve('{execution}','worker-image',1,99);"),
                            ('trade-processor', f"SELECT lab_execution.settle('{execution}');")]:
            identity = f['identities'][role]
            require(sql(identity['username'], identity['password'], query), 'Synthetic settlement refused')
        before = fingerprint(sql, f['database_password'])
        ca_values = {name + '-ca.pem': Path(f[name]['ca']).read_bytes() for name in ('database', 'broker')}
        # Valid unrelated CA bytes, generated locally by the existing certificate helper.
        wrong = root / 'untrusted'
        wrong.mkdir()
        images.certificates(wrong, '127.0.0.1')
        untrusted = (wrong / 'ca.pem').read_bytes()
        secrets_list = [*passwords.values(), *f['broker']['passwords'].values(), f['database_password']]
        configs = {role: worker_config(role, f, passwords) for role in ('event-publisher', 'event-consumer')}

        def worker(role, config=None, values=None):
            value = config or configs[role]
            return WorkerImage(f, verified, root, role, value, values or ca_values,
                               secrets_list + [value['database_password'], value['broker_password']])

        def count(table):
            return int(admin('SELECT count(*) FROM lab_execution.' + table + ';'))

        def effects():
            return tuple(count(table) for table in ('consumer_inbox', 'trade_projection', 'position_projection'))

        def acknowledged():
            return int(admin('SELECT count(*) FROM lab_execution.events WHERE delivered_at IS NOT NULL;'))

        def blocked(role):
            return admin(f"SELECT count(*) FROM pg_stat_activity WHERE usename='{role}' AND wait_event_type='Lock';") == '1'

        def encrypted(role):
            return admin(f"SELECT count(*) FROM pg_stat_activity a JOIN pg_stat_ssl s USING(pid) WHERE a.usename='{role}' AND s.ssl AND s.version IN ('TLSv1.2','TLSv1.3');") == '1'

        async with administration(f) as (nc, gate):
            js = nc.jetstream()
            await js.add_stream(config=StreamConfig(name=STREAM, subjects=SUBJECTS, storage=StorageType.FILE,
                max_bytes=8388608, max_msgs=10000, max_age=86400, discard=DiscardPolicy.NEW,
                duplicate_window=1.0, num_replicas=1, max_msg_size=8192))
            await js.add_consumer(STREAM, config=ConsumerConfig(durable_name='ACCOUNT_A',
                filter_subjects=['/accounts/22214/trades', '/accounts/22214/positions'],
                ack_policy=AckPolicy.EXPLICIT, ack_wait=1.0, max_ack_pending=32, max_deliver=-1))
            phase('negative_cases')
            for role in configs:
                for kind in NEGATIVES:
                    config, values = negative_config(configs[role], kind, ca_values, untrusted)
                    with worker(role, config, values).run() as w:
                        await until(lambda: not w.running(), 'negative worker termination', seconds=20)
                        check(w.state()['ExitCode'] == 2 and w.logs() == ['starting', 'terminal'],
                              role.replace('-', '_') + '_' + kind + '_terminal_rejection')
                    check(acknowledged() == 0 and effects() == (0, 0, 0) and
                          (await js.stream_info(STREAM)).state.messages == 0,
                          role.replace('-', '_') + '_' + kind + '_no_effects')
            phase('publisher_gate')
            await gate.execute('SELECT pg_advisory_lock(41901)')
            admin("CREATE FUNCTION lab_execution.image_gate() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN PERFORM pg_advisory_xact_lock(41901); RETURN NEW; END $$; CREATE TRIGGER image_gate BEFORE UPDATE OF delivered_at ON lab_execution.events FOR EACH ROW EXECUTE FUNCTION lab_execution.image_gate();")
            with worker('event-publisher').run() as w:
                await until(lambda: blocked('event_publisher'), 'publisher acknowledgment gate')
                w.verify_restrictions()
                checkpoint(checks, 'publisher_restricted_nonroot_private_materialization_verified')
                check(encrypted('event_publisher'), 'publisher_sql_session_verified_encrypted')
                check((await js.stream_info(STREAM)).state.messages == 1, 'broker_accepts_before_publisher_sql_ack')
                w.signal('SIGKILL', 137)
            check(acknowledged() == 0, 'killed_publisher_has_no_sql_ack')
            await gate.execute('SELECT pg_advisory_unlock(41901)')
            admin('DROP TRIGGER image_gate ON lab_execution.events; DROP FUNCTION lab_execution.image_gate();')
            await asyncio.sleep(2.2)
            phase('publisher_restart')
            with worker('event-publisher').run() as w:
                await until(lambda: acknowledged() == 2, 'publisher replacement drain')
                check((await js.stream_info(STREAM)).state.messages == 3, 'same_image_replays_after_broker_dedupe_window')
                w.signal('SIGTERM', 0)
            phase('consumer_precommit')
            await gate.execute('SELECT pg_advisory_lock(41902)')
            admin("CREATE FUNCTION lab_execution.image_gate() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN PERFORM pg_advisory_xact_lock(41902); RETURN NEW; END $$; CREATE TRIGGER image_gate BEFORE INSERT ON lab_execution.trade_projection FOR EACH ROW EXECUTE FUNCTION lab_execution.image_gate();")
            with worker('event-consumer').run() as w:
                await until(lambda: blocked('event_consumer_a'), 'consumer precommit gate')
                w.verify_restrictions()
                checkpoint(checks, 'consumer_restricted_nonroot_private_materialization_verified')
                check(encrypted('event_consumer_a'), 'consumer_sql_session_verified_encrypted')
                check((await js.consumer_info(STREAM, 'ACCOUNT_A')).num_ack_pending >= 1, 'consumer_precommit_has_unacked_delivery')
                w.signal('SIGKILL', 137)
            check(effects() == (0, 0, 0), 'precommit_kill_rolls_back_inbox_and_projection')
            await gate.execute('SELECT pg_advisory_unlock(41902)')
            admin('DROP TRIGGER image_gate ON lab_execution.trade_projection; DROP FUNCTION lab_execution.image_gate();')
            phase('consumer_postcommit_disable')
            await asyncio.to_thread(f['set_consumer_ack_allowed'], False)
            checkpoint(checks, 'scoped_consumer_ack_permission_fault_confirmed_by_broker_probe')
            try:
                phase('consumer_postcommit_probe')
                initial = await js.consumer_info(STREAM, 'ACCOUNT_A')
                phase('consumer_postcommit_start')
                with worker('event-consumer').run() as w:
                    phase('consumer_postcommit_window')
                    async def committed():
                        cursor = await gate.execute("SELECT count(*) FROM lab_execution.consumer_inbox WHERE login_role='event_consumer_a' AND event_id=%s", (execution + ':trade',))
                        return (await cursor.fetchone())[0] == 1
                    await until(committed, 'committed consumer effect before broker ack')
                    info = await js.consumer_info(STREAM, 'ACCOUNT_A')
                    delivered = await js.get_msg(STREAM, seq=info.delivered.stream_seq)
                    cursor = await gate.execute("SELECT (SELECT count(*) FROM lab_execution.consumer_inbox), (SELECT count(*) FROM lab_execution.trade_projection WHERE login_role='event_consumer_a' AND event_id=%s), (SELECT count(*) FROM lab_execution.position_projection)", (execution + ':trade',))
                    committed_effects = tuple(await cursor.fetchone())
                    check(postcommit_visible(w.running(), committed_effects, initial, info, delivered, execution),
                          'committed_effect_visible_while_ack_gate_holds_running_worker')
                    w.signal('SIGKILL', 137)
                check(effects() == (1, 1, 0), 'postcommit_kill_preserves_exactly_one_effect')
            finally:
                interrupted_phase = PHASE
                phase('consumer_postcommit_restore')
                await asyncio.to_thread(f['set_consumer_ack_allowed'], True)
                phase(interrupted_phase)
            checkpoint(checks, 'scoped_consumer_ack_permission_restored_and_confirmed')
            phase('consumer_restart')

            async def drained():
                info = await js.consumer_info(STREAM, 'ACCOUNT_A')
                return info.num_pending == 0 and info.num_ack_pending == 0 and effects() == (2, 1, 1)

            with worker('event-consumer').run() as w:
                await until(drained, 'replacement consumer drain')
                w.signal('SIGTERM', 0)
            check(effects() == (2, 1, 1), 'consumer_same_image_recovery_deduplicates_committed_effect')
            phase('idle_restart')
            with worker('event-publisher').run() as p, worker('event-consumer').run() as c:
                await until(lambda: 'running' in p.logs() and 'running' in c.logs(), 'idle worker restart')
                p.signal('SIGTERM', 0)
                c.signal('SIGTERM', 0)
            check(effects() == (2, 1, 1) and acknowledged() == 2 and
                  (await js.stream_info(STREAM)).state.messages == 3, 'idle_same_image_restart_no_extra_delivery_effects')
            check(fingerprint(sql, f['database_password']) == before, 'delivery_recovery_does_not_rebook_business_trade')
            check(count('receipts') == 1, 'one_authoritative_settlement_receipt')
        phase('cleanup')
    checkpoint(checks, 'owned_workers_peers_network_and_private_files_cleaned')
    return {'status': 'passed', 'source_commit': manifest['source_commit'],
            'worker_images': {role: verified[role] for role in ('event-publisher', 'event-consumer')},
            'peer_images': peer_images,
            'checks': checks, 'counts': {'outbox': 2, 'broker_messages': 3, 'inbox': 2, 'trade_projection': 1, 'position_projection': 1},
            'source_sha256': {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                              for path in (Path(__file__).resolve(), ROOT/'scripts/security-lab/worker_image_fixture.py',
                                           ROOT/'scripts/security-lab/delivery_worker.py', ROOT/'scripts/security-lab/event_delivery.py',
                                           MIGRATION, SETTLEMENT, EVENTS, CONSUMER)},
            'limitations': ['Hosted Docker image acceptance; no Kubernetes composition claim.',
                            'Postcommit fault denies only broker ACK permission; actual SIGKILL, not host power loss.',
                            'Synthetic settlement and SQL gates; same-database reference projection.']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-dir', type=Path, required=True)
    parser.add_argument('--images', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        raise ValueError('Evidence already exists')
    try:
        result = asyncio.run(campaign(args.runtime_dir, json.loads(args.images.read_text())))
    except Exception as error:
        # Deliberately no traceback, driver log, URLs, credentials or SQL values.
        result = failure(error)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open('x') as output:
        json.dump(result, output, indent=2)
        output.write('\n')
    print(json.dumps(result))
    return 0 if result['status'] == 'passed' else 1


if __name__ == '__main__':
    raise SystemExit(main())
