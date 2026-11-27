"""Hosted trade-processor image acceptance: real TLS, reservations and SQL effects."""
import argparse
import datetime
import hashlib
import http.client
import json
import os
from pathlib import Path
import ssl
import tempfile
import time
import uuid

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
import jwt

import portability
import verify_runtime_images as images
from verify_bootstrap import fingerprint, require
from verify_execution_reservations import MIGRATION, SETTLEMENT
from verify_execution_events import EVENTS
from verify_position_image import rejected_database_startup, Failure as RuntimeFailure
from verify_position_image import startup_diagnostic, STARTUP_MARKERS, LOG_MARKERS
from verify_worker_images import peer_diagnostic
from worker_image_fixture import fixture, FixtureFailure

ROOT = Path(__file__).resolve().parents[2]
ROLE = 'trade-processor'
KEYS = ('config.json', 'database-ca.pem', 'public.pem', 'tls.p12')
ISSUER = 'https://identity.example.test/processor-image'
AUDIENCE = 'traderx-execution'
MATCHER_SUBJECT = 'lab-matcher-service'
VARIANTS = ('malformed', 'invalid_signature', 'foreign_issuer', 'foreign_audience', 'expired', 'wrong_subject')
LEGACY = {'legacy_trade': '/trade/', 'legacy_order': '/tradeservice/order', 'legacy_health': '/system/health',
          'legacy_metrics': '/metrics', 'legacy_error': '/error'}
PHASES = frozenset(('configuration', 'image', 'fixture', 'reservation', 'wrong_database_ca', 'startup',
                   'restrictions', 'authorization', 'settlement', 'replay', 'restart', 'sql_tls', 'cleanup'))
PHASE = 'configuration'
DIAGNOSTIC = {}
RUNTIME_ERRORS = frozenset(('image_manifest_invalid', 'image_manifest_drift', 'loaded_image_changed',
    'private_projection_failed', 'private_output_detected', 'java_startup_failed', 'java_startup_timeout',
    'worker_cleanup_ownership', 'http_body_bound'))
CHECKS = frozenset(('immutable_processor_image_revalidated', 'scoped_matcher_reserves_two_synthetic_orders',
    'untrusted_database_ca_terminates_before_http', 'untrusted_database_ca_no_effects', 'verified_https_database_health_up',
    'restricted_private_processor_runtime', 'credentials_absent_from_argv_and_environment',
    'untrusted_https_ca_rejected', 'mismatched_https_hostname_rejected', 'anonymous_execution_denied',
    'body_override_denied', 'invalid_execution_identifier_denied', 'unknown_execution_denied', 'execution_get_denied',
    'correct_matcher_receives_execution_receipt', 'one_authoritative_trade_position_and_receipt',
    'settlement_preserves_unrelated_business_rows_and_all_reservations',
    'two_committed_account_outbox_events', 'unrelated_reserved_order_remains_untouched', 'duplicate_execution_is_idempotent',
    'same_immutable_processor_restarts_and_replays_idempotently', 'all_runtime_sql_connections_encrypted',
    'processor_sql_identity_nonadministrative', 'owned_processor_image_fixture_cleaned')) | frozenset(
        name+'_denied' for name in (*VARIANTS, *LEGACY)) | frozenset(
        name+'_no_effects' for name in ('anonymous', *VARIANTS, 'body_override', 'invalid_execution_identifier',
                                      'unknown_execution', 'execution_get', *LEGACY))


class Failure(RuntimeError):
    pass


def phase(name):
    global PHASE
    if name not in PHASES: raise ValueError('Unknown processor phase')
    PHASE = name


def failure(error):
    code = str(error) if isinstance(error, (Failure, RuntimeFailure)) else ''
    value = {'status': 'failed', 'phase': PHASE, 'error': code if code in CHECKS | RUNTIME_ERRORS else 'processor_image_campaign_failed'}
    diagnostic = getattr(error, 'runtime_diagnostic', None) or DIAGNOSTIC
    if diagnostic: value['runtime'] = bounded_runtime(diagnostic)
    if isinstance(error, FixtureFailure): value['peer'] = peer_diagnostic(error.details)
    return value


def bounded_runtime(value):
    value = value if isinstance(value, dict) else {}
    def strings(name):
        items = value.get(name)
        return [item for item in items[:32] if isinstance(item, str)] if isinstance(items, list) else []
    code = value.get('exit_code')
    classes = startup_diagnostic('\n'.join(strings('exception_classes')))['exception_classes']
    return {'running': value.get('running') if type(value.get('running')) is bool else None,
            'oom_killed': value.get('oom_killed') if type(value.get('oom_killed')) is bool else None,
            'exit_code': code if type(code) is int and 0 <= code <= 255 else None,
            'tls_rejection': value.get('tls_rejection') is True,
            'markers': [marker for marker in LOG_MARKERS.values() if marker in strings('markers')],
            'categories': sorted(set(strings('categories')) & set(STARTUP_MARKERS.values())),
            'exception_classes': classes}


def config(f, password):
    credentials = f['identities'][ROLE]
    return {'version': 1, 'role': ROLE,
            'database': {'host': 'database', 'port': 5432, 'name': 'traderx',
                         'username': credentials['username'], 'password': credentials['password']},
            'identity': {'issuer': ISSUER, 'audience': AUDIENCE, 'matcher_subject': MATCHER_SUBJECT,
                         'key_not_after': datetime.datetime.fromtimestamp(time.time()+1800, datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')},
            'tls': {'password': password}}


def token(key, variant=None):
    if variant == 'malformed': return 'not.a.jwt'
    now = int(time.time())
    claims = {'sub': MATCHER_SUBJECT, 'iss': ISSUER, 'aud': AUDIENCE, 'iat': now-5, 'exp': now+900}
    if variant == 'foreign_issuer': claims['iss'] = 'https://foreign.example.test'
    elif variant == 'foreign_audience': claims['aud'] = 'traderx-api'
    elif variant == 'expired': claims.update(iat=now-300, exp=now-60)
    elif variant == 'wrong_subject': claims['sub'] = 'lab-trader'
    elif variant not in (None, 'invalid_signature'): raise ValueError('Unknown identity variant')
    return jwt.encode(claims, key, algorithm='RS256')


def snapshot(f):
    result = fingerprint(f['sql'], f['database_password'])
    for table in ('reservations', 'receipts', 'events'):
        result['execution_'+table] = f['admin']("SELECT count(*),coalesce(md5(string_agg(x::text,'' ORDER BY x::text)),'empty') FROM (SELECT to_jsonb(t) x FROM lab_execution."+table+' t) s;')
    return result


def protected_snapshot(f, execution):
    """Only the one reserved trade, position and order may change on settlement."""
    if str(uuid.UUID(execution)) != execution:
        raise ValueError('Canonical execution identifier required')
    predicates = {'accounts': '', 'accountusers': '',
                  'trades': f" WHERE id <> '{execution}'",
                  'positions': " WHERE NOT (accountid=62654 AND security='IBM')",
                  'orderbook': " WHERE orderid <> 'processor-image-main'",
                  'lab_execution.reservations': ''}
    result = {}
    for table, predicate in predicates.items():
        result[table] = f['admin']("SELECT count(*),coalesce(md5(string_agg(x::text,'' ORDER BY x::text)),'empty') "
                                  'FROM (SELECT to_jsonb(t) x FROM '+table+' t'+predicate+') s;')
    return result


def isolated_settlement(observation, protected_before, protected_after):
    required = {'accounts', 'accountusers', 'trades', 'positions', 'orderbook', 'lab_execution.reservations'}
    return (settled_once(observation) and set(protected_before) == required and
            set(protected_after) == required and protected_before == protected_after)


def reservation_fixture(f):
    for path in (MIGRATION, SETTLEMENT, EVENTS): f['admin'](path.read_text())
    ids = {'main': str(uuid.uuid4()), 'canary': str(uuid.uuid4())}
    identity = f['identities']['order-matcher']
    for name, account, quantity in (('main', 62654, 2), ('canary', 22214, 1)):
        order = 'processor-image-'+name
        f['admin'](f"INSERT INTO orderbook(orderid,accountid,security,side,quantity,remainingquantity,limitprice,status,createdat,updatedat,acceptedsubject,acceptedissuer,acceptedterms) VALUES ('{order}',{account},'IBM','Buy',{quantity},{quantity},100,'NEW',now(),now(),'synthetic-trader','{ISSUER}','bounded-fixture');")
        result = require(f['sql'](identity['username'], identity['password'],
            f"SELECT lab_execution.reserve('{ids[name]}','{order}',{quantity},99);"), 'Synthetic matcher reservation failed')
        if result != ids[name]: raise Failure('scoped_matcher_reserves_two_synthetic_orders')
    return ids


def settlement_observation(f, execution):
    """Authority is SQL state, never an HTTP response or alert alone."""
    return json.loads(f['admin'](f"""SELECT json_build_object(
      'receipts',(SELECT count(*) FROM lab_execution.receipts),
      'receiptMatches',(SELECT count(*) FROM lab_execution.receipts WHERE execution_id='{execution}' AND trade_id='{execution}'),
      'tradeMatches',(SELECT count(*) FROM trades WHERE id='{execution}' AND accountid=62654 AND security='IBM' AND side='Buy' AND quantity=2 AND price=99 AND state='Settled'),
      'positionMatches',(SELECT count(*) FROM positions WHERE accountid=62654 AND security='IBM' AND quantity=2 AND averagecostbasis=99),
      'orderMatches',(SELECT count(*) FROM orderbook WHERE orderid='processor-image-main' AND remainingquantity=0 AND status='FILLED' AND lastfillquantity=2 AND lastexecutionprice=99),
      'events',(SELECT coalesce(json_agg(json_build_object('id',event_id,'execution',execution_id,'kind',event_kind,'topic',topic,'account',payload->'accountId','quantity',payload->'quantity','delivered',delivered_at,'attempts',attempts) ORDER BY event_sequence),'[]'::json) FROM lab_execution.events));"""))


def settled_once(value):
    return all(type(value.get(name)) is int and value[name] == 1
               for name in ('receipts', 'receiptMatches', 'tradeMatches', 'positionMatches', 'orderMatches'))


def outbox_matches(events, execution):
    expected = [{'id': execution+':trade', 'execution': execution, 'kind': 'trade.settled',
                 'topic': '/accounts/62654/trades', 'account': 62654, 'quantity': 2, 'delivered': None, 'attempts': 0},
                {'id': execution+':position', 'execution': execution, 'kind': 'position.updated',
                 'topic': '/accounts/62654/positions', 'account': 62654, 'quantity': 2, 'delivered': None, 'attempts': 0}]
    return events == expected


def campaign(runtime, manifest):
    from java_image_fixture import verified_image, certificate_material, JavaImage, private_java_probe
    if not portability.isolated_linux() or os.environ.get('GITHUB_ACTIONS') != 'true':
        raise ValueError('Isolated hosted Linux required')
    checks = []
    def check(value, name):
        if name not in CHECKS: raise ValueError('Unknown fixed check')
        if not value: raise Failure(name)
        checks.append(name)
        print(json.dumps({'type': 'processor_image_checkpoint', 'check': name, 'result': 'passed', 'campaign_status': 'incomplete'}), flush=True)
    phase('image')
    identity = verified_image(manifest, images.Docker(runtime), ROLE)
    check(True, 'immutable_processor_image_revalidated')
    phase('fixture')
    with fixture(runtime) as f, tempfile.TemporaryDirectory(prefix='processor-image-private-', dir=runtime) as temporary:
        root = Path(temporary)
        phase('reservation'); ids = reservation_fixture(f)
        check(f['admin']('SELECT count(*) FROM lab_execution.reservations;') == '2', 'scoped_matcher_reserves_two_synthetic_orders')
        before = snapshot(f)
        ca, p12, password = certificate_material(ROLE)
        context = ssl.create_default_context(cadata=ca.decode())
        key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        other = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        configuration = config(f, password)
        materials = {'database-ca.pem': Path(f['database']['ca']).read_bytes(), 'tls.p12': p12,
                     'public.pem': key.public_key().public_bytes(serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo)}
        def image(values=None): return JavaImage(f, root, identity, configuration, values or materials)
        def diagnosed(app):
            DIAGNOSTIC.clear(); DIAGNOSTIC.update(app.diagnostics())
        phase('wrong_database_ca')
        with image(dict(materials, **{'database-ca.pem': ca})).run() as app:
            deadline, served_http = time.monotonic()+90, False
            while app.inspect()['State'].get('Running') is True and time.monotonic() < deadline:
                try: app.request(context, '/actuator/health'); served_http = True
                except (OSError, http.client.HTTPException): pass
                time.sleep(.25)
            diagnosed(app)
            check(rejected_database_startup(DIAGNOSTIC, served_http), 'untrusted_database_ca_terminates_before_http')
        DIAGNOSTIC.clear()
        check(snapshot(f) == before, 'untrusted_database_ca_no_effects')
        phase('startup')
        with image().run() as app:
            try:
                app.ready(context); check(True, 'verified_https_database_health_up')
                phase('restrictions')
                inspected = app.inspect()
                probe = json.loads(app.docker('exec', app.name, '/usr/local/bin/python', '-c', images.PRIVATE_PROBE).stdout)
                images.check_restrictions(inspected, probe)
                private = json.loads(app.docker('exec', app.name, '/usr/local/bin/python', '-c', private_java_probe(ROLE)).stdout)
                check(private['files'] == {name: [10001, 10001, 0o600] for name in KEYS} and
                      private['properties'] == [10001, 10001, 0o600] and private['properties_directory'] == [10001, 10001, 0o700] and
                      private['listener'] is True and inspected['HostConfig']['Memory'] == 768*1024*1024 and
                      inspected['HostConfig']['PidsLimit'] == 128 and not inspected['HostConfig'].get('PortBindings'), 'restricted_private_processor_runtime')
                check(private['credentials_exposed'] is False, 'credentials_absent_from_argv_and_environment')
                for name, client, hostname in (('untrusted_https_ca_rejected', ssl.create_default_context(), ROLE),
                                                ('mismatched_https_hostname_rejected', context, 'wrong-processor')):
                    rejected = False
                    try: app.request(client, '/actuator/health', hostname=hostname)
                    except ssl.SSLCertVerificationError: rejected = True
                    check(rejected, name)
                phase('authorization')
                path = '/internal/executions/'+ids['main']
                def deny(name, expected, bearer=None, route=path, body=None, method='POST', headers=None):
                    status, _ = app.request(context, route, bearer=bearer, method=method, body=body, headers=headers)
                    check(status == expected, 'anonymous_execution_denied' if name == 'anonymous' else name+'_denied')
                    check(snapshot(f) == before, name+'_no_effects')
                deny('anonymous', 401)
                for variant in VARIANTS:
                    bearer = token(other if variant == 'invalid_signature' else key, variant)
                    deny(variant, 403 if variant == 'wrong_subject' else 401, bearer,
                         headers={'X-Service-Subject': MATCHER_SUBJECT} if variant == 'wrong_subject' else None)
                valid = token(key)
                deny('body_override', 400, valid, body=b'{"accountId":22214,"quantity":100,"price":1}')
                deny('invalid_execution_identifier', 400, valid, route='/internal/executions/not-a-uuid')
                deny('unknown_execution', 409, valid, route='/internal/executions/'+str(uuid.uuid4()))
                for name, route in LEGACY.items(): deny(name, 403, valid, route=route)
                deny('execution_get', 403, valid, method='GET')
                phase('settlement')
                protected_before = protected_snapshot(f, ids['main'])
                status, raw = app.request(context, path, bearer=valid, method='POST')
                receipt = {'executionId': ids['main'], 'tradeId': ids['main']}
                check(status == 200 and json.loads(raw) == receipt, 'correct_matcher_receives_execution_receipt')
                observation = settlement_observation(f, ids['main'])
                check(settled_once(observation), 'one_authoritative_trade_position_and_receipt')
                check(isolated_settlement(observation, protected_before, protected_snapshot(f, ids['main'])),
                      'settlement_preserves_unrelated_business_rows_and_all_reservations')
                check(outbox_matches(observation['events'], ids['main']), 'two_committed_account_outbox_events')
                check(f['admin']("SELECT remainingquantity||'|'||status FROM orderbook WHERE orderid='processor-image-canary';") == '1|NEW' and
                      f['admin'](f"SELECT count(*) FROM lab_execution.receipts WHERE execution_id='{ids['canary']}';") == '0', 'unrelated_reserved_order_remains_untouched')
                after = snapshot(f)
                phase('replay')
                status, raw = app.request(context, path, bearer=valid, method='POST')
                check(status == 200 and json.loads(raw) == receipt and snapshot(f) == after, 'duplicate_execution_is_idempotent')
                phase('sql_tls')
                role = f['identities'][ROLE]['username']
                counts = f['admin'](f"SELECT count(*),count(*) FILTER(WHERE s.ssl AND s.version IN ('TLSv1.2','TLSv1.3')) FROM pg_stat_activity a LEFT JOIN pg_stat_ssl s USING(pid) WHERE a.usename='{role}';").split('|')
                check(len(counts) == 2 and int(counts[0]) > 0 and counts[0] == counts[1], 'all_runtime_sql_connections_encrypted')
                check(f['admin'](f"SELECT rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls FROM pg_roles WHERE rolname='{role}';") == 'f', 'processor_sql_identity_nonadministrative')
            except Exception:
                diagnosed(app); raise
        phase('restart')
        with image().run() as app:
            try:
                app.ready(context)
                status, raw = app.request(context, path, bearer=token(key), method='POST')
                check(status == 200 and json.loads(raw) == receipt and snapshot(f) == after,
                      'same_immutable_processor_restarts_and_replays_idempotently')
            except Exception:
                diagnosed(app); raise
        peer_images = {name: f[name]['image'] for name in ('database', 'broker')}
        phase('cleanup')
    check(True, 'owned_processor_image_fixture_cleaned')
    return {'status': 'passed', 'source_commit': manifest['source_commit'], 'image': identity, 'peer_images': peer_images,
            'checks': checks, 'counts': {'reservations': 2, 'settlements': 1, 'outbox_events': 2},
            'source_sha256': {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in (
                Path(__file__).resolve(), ROOT/'scripts/security-lab/java_image_fixture.py', ROOT/'scripts/security-lab/java_runtime.py',
                ROOT/'scripts/security-lab/java_images.py', MIGRATION, SETTLEMENT, EVENTS)},
            'limitations': ['Signed fixture JWTs, not an actual Keycloak service grant or browser/matcher workflow.',
                            'Real packaged processor and scoped TLS SQL; synthetic accepted-order/reservation fixture.',
                            'Two SQL outbox rows committed; publishing/consumption is a separate accepted worker campaign.',
                            'Owned NATS peer unused; no Kubernetes cumulative deployment claim.']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-dir', type=Path, required=True); parser.add_argument('--image', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True); args = parser.parse_args()
    if args.output.exists(): raise ValueError('Evidence already exists')
    try: result = campaign(args.runtime_dir, json.loads(args.image.read_text()))
    except Exception as error: result = failure(error)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open('x') as output: json.dump(result, output, indent=2); output.write('\n')
    print(json.dumps(result)); return 0 if result['status'] == 'passed' else 1


if __name__ == '__main__': raise SystemExit(main())
