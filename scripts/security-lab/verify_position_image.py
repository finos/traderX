"""Hosted acceptance of the immutable protected position-service image."""
import argparse
from contextlib import contextmanager
import copy
import datetime
import hashlib
import http.client
import ipaddress
import json
import os
from pathlib import Path
import re
import secrets
import socket
import ssl
import subprocess
import tempfile
import time

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives.serialization import pkcs12
from cryptography.x509.oid import NameOID, ExtendedKeyUsageOID
import jwt

import integrated_deployment as compiler
import portability
import verify_runtime_images as images
from verify_bootstrap import fingerprint
from verify_worker_images import peer_diagnostic
from worker_image_fixture import fixture, FixtureFailure

ROOT = Path(__file__).resolve().parents[2]
ISSUER = 'https://identity.example.test/position-image'
AUDIENCE = 'traderx-api'
KEYS = ('config.json', 'database-ca.pem', 'entitlements.properties', 'public.pem', 'tls.p12')
PHASES = frozenset(('configuration', 'image', 'fixture', 'configuration_material', 'wrong_database_ca',
                   'startup', 'restrictions', 'authorization', 'sql_tls', 'cleanup'))
PHASE = 'configuration'
DIAGNOSTIC = {}
INVALID_TOKENS = ('invalid_signature', 'foreign_issuer', 'foreign_audience', 'expired')
CHECKS = frozenset(('immutable_position_image_revalidated', 'untrusted_database_ca_terminates_startup',
    'untrusted_database_ca_no_data_effects', 'verified_https_database_health_up',
    'restricted_runtime_and_private_materialization', 'no_credentials_in_argv_or_environment',
    'https_untrusted_client_ca_rejected', 'https_mismatched_hostname_rejected', 'operator_detailed_health_allowed',
    'reader_detailed_health_denied', 'operator_has_no_implicit_account_scope',
    'runtime_sql_connections_all_encrypted', 'runtime_sql_role_is_scoped_nonadmin',
    'all_reads_and_rejections_leave_business_data_unchanged', 'owned_image_fixture_cleaned')) | frozenset(
        kind + '_' + case for kind in ('positions', 'trades') for case in (
            'anonymous_denied', 'unknown_subject_denied', *[name + '_denied' for name in INVALID_TOKENS],
            'reader_collection_scoped', 'trader_collection_scoped', 'reader_own_account_scoped',
            'trader_own_account_scoped', 'reader_cross_account_denied', 'trader_cross_account_denied'))
ERRORS = CHECKS | frozenset(('hosted_linux_required', 'image_manifest_invalid', 'image_manifest_drift',
    'loaded_image_changed', 'private_projection_failed', 'private_output_detected', 'position_startup_failed',
    'position_startup_timeout', 'worker_cleanup_ownership', 'wrong_database_ca_still_running',
    'http_body_bound', 'fixture_read_rows_missing'))


def phase(name):
    global PHASE
    if name not in PHASES:
        raise ValueError('Unknown fixed phase')
    PHASE = name


class Failure(RuntimeError):
    pass


def failure(error):
    code = str(error) if isinstance(error, Failure) else ''
    result = {'status': 'failed', 'phase': PHASE, 'error': code if code in ERRORS else 'position_image_campaign_failed'}
    if DIAGNOSTIC:
        result['runtime'] = dict(DIAGNOSTIC)
    if isinstance(error, FixtureFailure):
        result['peer'] = peer_diagnostic(error.details)
    return result


def verified_image(manifest, docker):
    import java_images
    if (not isinstance(manifest, dict) or set(manifest) !=
            {'source_commit', 'image', 'runtime_reference', 'generated_root', 'build_report'} or
            not isinstance(manifest['source_commit'], str) or not re.fullmatch(r'[0-9a-f]{40}', manifest['source_commit'])):
        raise Failure('image_manifest_invalid')
    entry = manifest['image']
    if not isinstance(entry, dict) or set(entry) != {'image', 'oci_layout', 'secret', 'keys'}:
        raise Failure('image_manifest_invalid')
    inspected = java_images.inspect(entry['oci_layout'], manifest['runtime_reference'], manifest['source_commit'],
                                    manifest['generated_root'], manifest['build_report'])
    if inspected != entry:
        raise Failure('image_manifest_drift')
    layout = Path(entry['oci_layout'])
    descriptor = compiler.read_json(layout/'index.json')['manifests'][0]
    image = compiler.blob(layout, descriptor)
    loaded = json.loads(docker('image', 'inspect', '--format', '{{json .}}', manifest['runtime_reference']).stdout)
    return images.bind_loaded_image('position-service', loaded, descriptor, image['config']['digest'])


def certificate_material():
    now = datetime.datetime.now(datetime.timezone.utc)
    ca_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    issuer = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, 'Synthetic position image CA')])
    ca = (x509.CertificateBuilder().subject_name(issuer).issuer_name(issuer).public_key(ca_key.public_key())
          .serial_number(x509.random_serial_number()).not_valid_before(now-datetime.timedelta(minutes=1))
          .not_valid_after(now+datetime.timedelta(hours=1)).add_extension(x509.BasicConstraints(ca=True, path_length=0), True)
          .add_extension(x509.KeyUsage(False, False, False, False, False, True, True, None, None), True)
          .add_extension(x509.SubjectKeyIdentifier.from_public_key(ca_key.public_key()), False)
          .sign(ca_key, hashes.SHA256()))
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    leaf = (x509.CertificateBuilder().subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, 'position-service')]))
            .issuer_name(issuer).public_key(key.public_key()).serial_number(x509.random_serial_number())
            .not_valid_before(now-datetime.timedelta(minutes=1)).not_valid_after(now+datetime.timedelta(hours=1))
            .add_extension(x509.BasicConstraints(ca=False, path_length=None), True)
            .add_extension(x509.SubjectAlternativeName([x509.DNSName('position-service')]), False)
            .add_extension(x509.KeyUsage(True, False, True, False, False, False, False, None, None), True)
            .add_extension(x509.SubjectKeyIdentifier.from_public_key(key.public_key()), False)
            .add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(ca_key.public_key()), False)
            .add_extension(x509.ExtendedKeyUsage([ExtendedKeyUsageOID.SERVER_AUTH]), False).sign(ca_key, hashes.SHA256()))
    password = secrets.token_urlsafe(32)
    bundle = pkcs12.serialize_key_and_certificates(b'position-service', key, leaf, [ca],
                                                   serialization.BestAvailableEncryption(password.encode()))
    return ca.public_bytes(serialization.Encoding.PEM), bundle, password


def configuration(f, password):
    credentials = f['identities']['position-service']
    return {'version': 1, 'role': 'position-service',
            'database': {'host': 'database', 'port': 5432, 'name': 'traderx',
                         'username': credentials['username'], 'password': credentials['password']},
            'identity': {'issuer': ISSUER, 'audience': AUDIENCE,
                         'key_not_after': datetime.datetime.fromtimestamp(time.time()+1800, datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')},
            'tls': {'password': password}}


def token(key, subject='lab-reader', variant=None):
    now = int(time.time())
    claims = {'sub': subject, 'iss': ISSUER, 'aud': AUDIENCE, 'iat': now-5, 'exp': now+900}
    if variant == 'foreign_issuer': claims['iss'] = 'https://foreign.example.test'
    elif variant == 'foreign_audience': claims['aud'] = 'foreign-api'
    elif variant == 'expired': claims.update(iat=now-300, exp=now-60)
    elif variant not in (None, 'invalid_signature'): raise ValueError('Unknown token variant')
    return jwt.encode(claims, key, algorithm='RS256')


def projected(root, name, config, materials):
    content = {'config.json': compiler.encoded(config), **materials}
    if set(content) != set(KEYS): raise Failure('private_projection_failed')
    target = root/name
    target.mkdir(mode=0o750); target.chmod(0o750)
    for filename, data in content.items():
        path = target/filename; path.write_bytes(data); path.chmod(0o440)
    for command in (['sudo', '-n', 'chgrp', '10001', str(target)],
                    ['sudo', '-n', 'chown', '0:10001', *map(str, sorted(target.iterdir()))]):
        if subprocess.run(command, capture_output=True, timeout=10).returncode:
            raise Failure('private_projection_failed')
    return target


def launch_args(name, f, target, identity):
    args = images.launch_args(name, f['network'], f['owner'], target, identity)
    args[args.index('--memory')+1] = '768m'
    args[args.index('--pids-limit')+1] = '128'
    args = [value.replace('/tmp:rw,noexec,nosuid,nodev,uid=10001,gid=10001,mode=0700,size=8m',
                          '/tmp:rw,noexec,nosuid,nodev,uid=10001,gid=10001,mode=0700,size=64m') for value in args]
    return args[:-1] + ['--network-alias', 'position-service', args[-1]]


def request(address, context, path, bearer=None, hostname='position-service'):
    connection = http.client.HTTPSConnection(hostname, 18090, context=context, timeout=4)
    def connect():
        raw = socket.create_connection((address, 18090), timeout=4)
        try: connection.sock = context.wrap_socket(raw, server_hostname=hostname)
        except BaseException: raw.close(); raise
    connection.connect = connect
    try:
        connection.request('GET', path, headers={'Authorization': 'Bearer '+bearer} if bearer else {})
        response = connection.getresponse(); data = response.read(1024*1024+1)
        if len(data) > 1024*1024: raise Failure('http_body_bound')
        return response.status, data
    finally: connection.close()


def rows_match(raw, expected, kind, account):
    rows = json.loads(raw)
    if not isinstance(rows, list) or not rows or not expected: return False
    keys = ('accountId', 'security', 'quantity') if kind == 'positions' else ('id', 'accountId', 'security', 'side', 'quantity')
    if any(not isinstance(row, dict) or row.get('accountId') != account or not set(keys) <= set(row) for row in rows): return False
    return sorted(tuple(row[key] for key in keys) for row in rows) == sorted(tuple(row[key] for key in keys) for row in expected)


TLS_MARKERS = ('SSLHandshakeException', 'PKIX path building failed', 'unable to find valid certification path',
               'CertPathValidatorException', 'certificate verify failed')
LOG_MARKERS = {'Protected Java configuration refused; private details withheld.': 'configuration_refused',
               'APPLICATION FAILED TO START': 'spring_startup_failed', 'Started PositionServiceApplication': 'spring_started'}


def rejected_database_startup(diagnostic):
    return (not diagnostic['running'] and diagnostic['exit_code'] not in (None, 0, 2) and
            not diagnostic['oom_killed'] and diagnostic['tls_rejection'] and
            'configuration_refused' not in diagnostic['markers'])


class PositionImage:
    def __init__(self, f, root, identity, config, materials):
        self.f, self.docker, self.identity = f, f['docker'], identity
        self.name = 'traderx-position-image-' + secrets.token_hex(10)
        self.target = projected(root, self.name, config, materials)
        self.secrets = (config['database']['password'], config['tls']['password'])
        self.address = None

    def inspect(self): return json.loads(self.docker('inspect', self.name).stdout)[0]

    def diagnostics(self):
        state = self.inspect()['State']
        log = self.docker('logs', '--tail', '100', self.name)
        text = log.stdout+log.stderr
        if any(secret in text for secret in self.secrets): raise Failure('private_output_detected')
        code = state.get('ExitCode')
        return {'running': state.get('Running') is True, 'oom_killed': state.get('OOMKilled') is True,
                'exit_code': code if type(code) is int and 0 <= code <= 255 else None,
                'tls_rejection': any(marker in text for marker in TLS_MARKERS),
                'markers': [value for key, value in LOG_MARKERS.items() if key in text]}

    def cleanup(self):
        label = self.docker('inspect', '--format', '{{index .Config.Labels "'+images.LABEL+'"}}', self.name, check=False)
        if label.returncode:
            if 'No such' not in label.stderr or self.docker('ps', '-aq', '--filter', 'name=^/'+self.name+'$').stdout.strip():
                raise Failure('worker_cleanup_ownership')
            return
        if label.stdout.strip() != self.f['owner']: raise Failure('worker_cleanup_ownership')
        try: self.diagnostics()
        finally: self.docker('rm', '-f', self.name)

    @contextmanager
    def run(self):
        try:
            self.docker(*launch_args(self.name, self.f, self.target, self.identity['runtime_id']))
            value = self.inspect()
            if (value['Image'] not in (self.identity['runtime_id'], self.identity['config_digest']) or
                    value['Config']['Image'] != self.identity['runtime_id']): raise Failure('loaded_image_changed')
            self.address = value['NetworkSettings']['Networks'][self.f['network']]['IPAddress']
            ipaddress.IPv4Address(self.address)
            yield self
        except Exception:
            try: DIAGNOSTIC.update(self.diagnostics())
            except Exception: pass
            raise
        finally: self.cleanup()

    def ready(self, context):
        deadline = time.monotonic()+90
        while time.monotonic() < deadline:
            if self.inspect()['State'].get('Running') is not True: raise Failure('position_startup_failed')
            try:
                status, raw = request(self.address, context, '/actuator/health')
                if status == 200 and json.loads(raw).get('status') == 'UP': return
            except (OSError, http.client.HTTPException, ValueError): pass
            time.sleep(.25)
        raise Failure('position_startup_timeout')


PRIVATE_JAVA_PROBE = '''import json,os,stat
from pathlib import Path
def mode(path):
 s=os.stat(path);return [s.st_uid,s.st_gid,stat.S_IMODE(s.st_mode)]
c=json.loads(Path('/run/private/config/config.json').read_bytes())
properties=dict(line.split('=',1) for line in Path('/run/private/application.properties').read_text().splitlines())
secrets=[c['database']['password'].encode(),c['tls']['password'].encode()]
exposed=Path('/proc/1/cmdline').read_bytes()+Path('/proc/1/environ').read_bytes()
print(json.dumps({'files':{p.name:mode(p) for p in Path('/run/private/config').iterdir()},
 'properties':mode('/run/private/application.properties'),'credentials_exposed':any(s in exposed for s in secrets),
 'listener':properties.get('server.address')=='0.0.0.0' and properties.get('server.port')=='18090' and properties.get('server.ssl.enabled')=='true'}))
'''


def campaign(runtime, manifest):
    if not portability.isolated_linux() or os.environ.get('GITHUB_ACTIONS') != 'true': raise Failure('hosted_linux_required')
    checks = []
    def check(value, name):
        if name not in CHECKS: raise ValueError('Unknown fixed acceptance check')
        if not value: raise Failure(name)
        checks.append(name)
        print(json.dumps({'type': 'position_image_checkpoint', 'check': name, 'result': 'passed', 'campaign_status': 'incomplete'}), flush=True)
    phase('image')
    identity = verified_image(manifest, images.Docker(runtime))
    check(True, 'immutable_position_image_revalidated')
    phase('fixture')
    with fixture(runtime) as f, tempfile.TemporaryDirectory(prefix='position-image-private-', dir=runtime) as temp:
        root = Path(temp); phase('configuration_material')
        ca, bundle, password = certificate_material()
        context = ssl.create_default_context(cadata=ca.decode())
        signing = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        alternate = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        config = configuration(f, password)
        materials = {'database-ca.pem': Path(f['database']['ca']).read_bytes(), 'tls.p12': bundle,
            'public.pem': signing.public_key().public_bytes(serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo),
            'entitlements.properties': b'lab-reader=read-only:22214\nlab-trader=trader:62654\nlab-operator=operator:\n'}
        # C3 has no positions for 62654. Dedicated synthetic read fixtures keep
        # both account proofs nonempty without substituting an HTTP business API.
        for account in (22214, 62654):
            f['admin'](f"INSERT INTO positions(accountid,security,quantity,averagecostbasis,updated) VALUES ({account},'LABIMAGE',1,99,now()); INSERT INTO trades(id,accountid,security,side,quantity,price,created,updated,state) VALUES ('position-image-{account}',{account},'LABIMAGE','Buy',1,99,now(),now(),'Settled');")
        before = fingerprint(f['sql'], f['database_password'])
        expected = {}
        for kind in ('positions', 'trades'):
            for account in (22214, 62654):
                fields = "'accountId',accountid,'security',security,'quantity',quantity"
                if kind == 'trades': fields += ",'id',id,'side',side"
                expected[kind, account] = json.loads(f['admin'](f"SELECT coalesce(json_agg(json_build_object({fields})),'[]'::json) FROM {kind} WHERE accountid={account};"))
                if not expected[kind, account]: raise Failure('fixture_read_rows_missing')
        phase('wrong_database_ca')
        wrong_materials = dict(materials, **{'database-ca.pem': ca})
        with PositionImage(f, root, identity, config, wrong_materials).run() as app:
            deadline = time.monotonic()+90
            while app.inspect()['State'].get('Running') is True and time.monotonic() < deadline: time.sleep(.25)
            diagnostic = app.diagnostics()
            check(rejected_database_startup(diagnostic), 'untrusted_database_ca_terminates_startup')
        check(fingerprint(f['sql'], f['database_password']) == before, 'untrusted_database_ca_no_data_effects')
        phase('startup')
        with PositionImage(f, root, identity, config, materials).run() as app:
            app.ready(context); check(True, 'verified_https_database_health_up')
            phase('restrictions')
            inspected = app.inspect()
            probe = json.loads(app.docker('exec', app.name, '/usr/local/bin/python', '-c', images.PRIVATE_PROBE).stdout)
            images.check_restrictions(inspected, probe)
            private = json.loads(app.docker('exec', app.name, '/usr/local/bin/python', '-c', PRIVATE_JAVA_PROBE).stdout)
            check(private['files'] == {name: [10001, 10001, 0o600] for name in KEYS} and
                  private['properties'] == [10001, 10001, 0o600] and
                  private['listener'] is True and
                  inspected['HostConfig']['Memory'] == 768*1024*1024 and inspected['HostConfig']['PidsLimit'] == 128 and
                  not inspected['HostConfig'].get('PortBindings'), 'restricted_runtime_and_private_materialization')
            check(private['credentials_exposed'] is False, 'no_credentials_in_argv_or_environment')
            for name, bad_context, hostname in (
                    ('https_untrusted_client_ca_rejected', ssl.create_default_context(), 'position-service'),
                    ('https_mismatched_hostname_rejected', context, 'wrong-position-service')):
                rejected = False
                try: request(app.address, bad_context, '/actuator/health', hostname=hostname)
                except ssl.SSLCertVerificationError: rejected = True
                check(rejected, name)
            phase('authorization')
            for kind in ('positions', 'trades'):
                check(request(app.address, context, '/'+kind+'/')[0] == 401, kind+'_anonymous_denied')
                for variant in INVALID_TOKENS:
                    bad = token(alternate if variant == 'invalid_signature' else signing, variant=variant)
                    check(request(app.address, context, '/'+kind+'/', bad)[0] == 401, kind+'_'+variant+'_denied')
                check(request(app.address, context, '/'+kind+'/', token(signing, 'unknown-subject'))[0] == 403, kind+'_unknown_subject_denied')
                for role, account, other in (('reader', 22214, 62654), ('trader', 62654, 22214)):
                    bearer = token(signing, 'lab-'+role)
                    for suffix, label in (('', 'collection_scoped'), (str(account), 'own_account_scoped')):
                        status, raw = request(app.address, context, '/'+kind+'/'+suffix, bearer)
                        check(status == 200 and rows_match(raw, expected[kind, account], kind, account), kind+'_'+role+'_'+label)
                    check(request(app.address, context, '/'+kind+'/'+str(other), bearer)[0] == 403, kind+'_'+role+'_cross_account_denied')
            operator = token(signing, 'lab-operator')
            check(request(app.address, context, '/health/ready', operator) == (200, b'true'), 'operator_detailed_health_allowed')
            check(request(app.address, context, '/health/ready', token(signing))[0] == 403, 'reader_detailed_health_denied')
            check(request(app.address, context, '/positions/', operator) == (200, b'[]') and
                  request(app.address, context, '/positions/22214', operator)[0] == 403, 'operator_has_no_implicit_account_scope')
            phase('sql_tls')
            role = f['identities']['position-service']['username']
            counts = f['admin'](f"SELECT count(*),count(*) FILTER(WHERE s.ssl AND s.version IN ('TLSv1.2','TLSv1.3')) FROM pg_stat_activity a LEFT JOIN pg_stat_ssl s USING(pid) WHERE a.usename='{role}';").split('|')
            check(len(counts) == 2 and int(counts[0]) > 0 and counts[0] == counts[1], 'runtime_sql_connections_all_encrypted')
            flags = f['admin'](f"SELECT rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls FROM pg_roles WHERE rolname='{role}';")
            check(flags == 'f', 'runtime_sql_role_is_scoped_nonadmin')
            check(fingerprint(f['sql'], f['database_password']) == before, 'all_reads_and_rejections_leave_business_data_unchanged')
        peer_images = {name: f[name]['image'] for name in ('database', 'broker')}
        phase('cleanup')
    check(True, 'owned_image_fixture_cleaned')
    return {'status': 'passed', 'source_commit': manifest['source_commit'], 'image': identity, 'peer_images': peer_images,
            'checks': checks, 'resource_limits': {'memory_mib': 768, 'pids': 128, 'tmp_mib': 64},
            'source_sha256': {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in (
                Path(__file__).resolve(), ROOT/'scripts/security-lab/worker_image_fixture.py', ROOT/'scripts/security-lab/java_runtime.py', ROOT/'scripts/security-lab/java_images.py')},
            'limitations': ['Signed fixture JWTs and static entitlements; no Keycloak or browser flow claim.',
                            'Actual read-only Java/SQL image; no Kubernetes deployment acceptance.',
                            'Shared owned peer fixture starts NATS, which this read-only campaign does not use.']}


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
