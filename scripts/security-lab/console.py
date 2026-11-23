#!/usr/bin/env python3
"""Loopback-bound fixed-action console; optional authenticated tunnel access."""
import argparse
from datetime import datetime, timezone
import fcntl
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import secrets
import shutil
import signal
import subprocess
import sys
import threading
import uuid
from urllib.parse import urlsplit

import lab
from resource_preflight import check as check_resources

UI = Path(__file__).parent / 'ui'
RUN_TIMEOUT = 900
SCENARIOS = [
    dict(id='nats', name='Test messaging permission boundaries', category='Broker authorization', duration='About 30–60 seconds',
         description='Compare permitted messages and rejected operations over TLS and secure WebSockets using two synthetic account identities.',
         scope='Isolated broker; live C3 messaging remains unchanged', effect='Starts and removes a restricted temporary broker on loopback ports. Uses disposable credentials and no trading consumers.',
         expected=['Authenticated market data and own-account messages arrive', 'Anonymous access, forged publications and cross-account subscriptions fail', 'Reconnect works; 28 checks produce evidence and the fixture is removed']),
    dict(id='sql', name='Test database permission boundaries', category='Least privilege', duration='About 30 seconds',
         description='Use four real service logins to verify SQL boundaries, then check the recorded credential rotation and retired-password rejection.',
         scope='Scoped service SQL roles and synthetic rollback transactions', effect='Reads live roles and Secret references; writes synthetic records inside rolled-back transactions. The account sequence advances once. No role or deployment changes.',
         expected=['Four application connection pools use non-admin identities', 'Permitted operations pass; 16 SQL authorization failures are verified', 'Admission rejects credential regressions; retired password fails']),
    dict(id='observability', name='Inspect telemetry storage & restrictions', category='Data preservation', duration='About 20 seconds',
         description='Check Grafana, Prometheus, Loki and Tempo process restrictions, persistent volumes and recorded historical-data retention.',
         scope='Four local telemetry stores and cutover evidence', effect='Reads live settings and private backup hashes, submits admission dry runs and creates/removes a temporary Grafana file. Does not migrate or restart stores.',
         expected=['Four non-root processes with read-only roots and no API tokens', 'Unsafe workload and storage changes are denied', 'Four PVCs are bound; file hashes and historical cutover checks verify']),
    dict(id='collector', name='Inspect namespace & collector boundary', category='Admission & evidence', duration='About 1–2 minutes',
         description='Test namespace-wide Restricted admission, the isolated collector exception and delivery of a fresh synthetic log to Loki.',
         scope='Application Restricted policy and infrastructure collector', effect='Submits server-side dry runs and briefly creates one small log-producing Pod. Does not change policies or restart data stores.',
         expected=['Unrelated-name privileged and host-access Pods are denied', 'Collector identity, image, paths and token are tightly constrained', 'A fresh log arrives; unrelated root Pods are rejected']),
    dict(id='database', name='Inspect database storage & restrictions', category='Data preservation', duration='About 15 seconds',
         description='Verify the PostgreSQL process and persistent volume, test unsafe deployment and Pod changes, and inspect the recorded backup/restore and restart proof.',
         scope='Local database workload and historical recovery evidence', effect='Reads workload/storage status, submits server-side dry runs and creates/removes one temporary database-container file. Does not migrate, restore or restart the database.',
         expected=['Non-root database with read-only root and no API token', 'Unsafe deployment, Pod and debug-container changes are denied', 'PVC is bound; recorded backup hash and restart recovery proof verify']),
    dict(id='support', name='Inspect gateway, UI & broker restrictions', category='Supporting services', duration='About 20 seconds',
         description='Inspect six supporting services and test admission for direct Pods and debug-container updates across both protected workload groups.',
         scope='Six services plus protected Pod labels and identities', effect='Reads process settings, submits server-side dry runs and creates/removes one temporary gateway test file. No deployment changes.',
         expected=['Six supporting processes run without root or API tokens', 'Eleven unsafe deployment changes are denied', 'Direct Pod and debug-container bypass attempts are denied']),
    dict(id='workloads', name='Inspect live service restrictions', category='Application hardening', duration='About 20 seconds',
         description='Verify the eight business services run without root, capabilities or Kubernetes tokens. Test that admission rejects weakened deployment settings.',
         scope='Eight named C3 business deployments', effect='Reads live process settings and submits server-side dry runs. Creates then removes one temporary test file in account-service.',
         expected=['Eight processes have the expected restrictions', 'Eleven unsafe deployment variations are denied', 'Writing to /tmp works; writing to the root filesystem fails']),
    dict(id='platform', name='Network & workload boundaries', category='Containment', duration='About 20 seconds',
         description='Watch a permitted connection succeed while an unrelated connection is denied. Verify that a privileged pod is rejected.',
         scope='Isolated platform fixtures', effect='Recreates three disposable test pods; does not change C3 policies.',
         expected=['Both clients connect before policy', 'Only the permitted client connects afterward', 'Restricted admission rejects an unsafe pod']),
    dict(id='waf', name='Three WAF modes. One request.', category='HTTP protection', duration='About 30–90 seconds',
         description='Compare Coraza and CRS in disabled, detection-only and blocking modes over verified TLS.',
         scope='Harmless recording backend', effect='Starts temporary local proxy/backend containers, then removes them. C3 traffic is unchanged.',
         expected=['Benign requests pass in every mode', 'Detection reports suspicious requests without blocking', 'Blocking returns 403; the backend receives nothing']),
    dict(id='baseline', name='Prove normal trading works', category='Positive control', duration='About 1–3 minutes',
         description='Run the full inherited C3 smoke suite, including trade submission, settlement, service APIs and observability.',
         scope='Current C3 lab deployment', effect='Creates and changes synthetic accounts, trades and positions. No production data is used.',
         expected=['Services and messaging are ready', 'Valid trades settle; invalid inputs are rejected', 'UI contracts and observability checks pass']),
]
SCENARIO_MODES = {s['id']: ('build' if s['id'] == 'waf' else 'fixture' if s['id'] == 'nats' else 'acceptance') for s in SCENARIOS}
for scenario in SCENARIOS:
    scenario['mode'] = SCENARIO_MODES[scenario['id']]
    scenario['effect'] += (' Requires isolated mode with C3 stopped.' if scenario['mode'] != 'acceptance' else ' Requires the full C3 lab running.')

ROADMAP = [
    dict(name='Pinned reference C3', status='Verified', detail='20 image pins and a passing full C3 smoke suite.'),
    dict(name='Network, admission and WAF fixtures', status='Verified', detail='Bounded demonstrations; these controls are not yet integrated across C3.'),
    dict(name='Hands-on console', status='Implemented', detail='Local fixed-action runner, progress and downloadable evidence.'),
    dict(name='Identity & business authorization', status='Planned', detail='OIDC roles, account ownership, trader/read-only/operator permissions; detailed service contracts still required.'),
    dict(name='Database & messaging permissions', status='In progress', detail='Four scoped PostgreSQL roles and Secret-backed service credentials implemented. Known bootstrap password retired; position-service rotation verified. Isolated NATS permission checks pass; live C3 broker authorization remains open.'),
    dict(name='Business-service restrictions', status='Implemented', detail='Eight services: non-root, read-only root, no tokens/capabilities, resource bounds and named-deployment admission. Use the live experiment to verify.'),
    dict(name='Supporting services & Pod admission', status='Implemented', detail='Gateway, frontend, API docs, NATS and two stateless telemetry services; direct-Pod/debug restrictions for protected labels/identities. Namespace Restricted coverage is verified separately.'),
    dict(name='Database storage & process restrictions', status='Implemented', detail='Persistent volume, private backup/restore, verified Pod-restart durability and restricted PostgreSQL identity. SQL least privilege remains separate.'),
    dict(name='Namespace Restricted & collector isolation', status='Implemented', detail='Application-wide Restricted v1.35; collector alone in an infrastructure namespace with exact admission restrictions and read-only pod/node/namespace access. The collector root/token exception remains explicit.'),
    dict(name='Telemetry storage & restrictions', status='Implemented', detail='Four preserved stores on PVCs, non-root/read-only processes and historical cutover evidence. Local volumes do not protect against cluster loss.'),
    dict(name='Complete deployment restrictions', status='Planned', detail='Full service-flow segmentation, integrated gateway and image trust checks remain open.'),
    dict(name='Runtime observation & enforcement', status='Planned', detail='Tetragon-compatible node setup, supported hooks and attributable outcomes.'),
    dict(name='Compromise, canary & recovery', status='Planned', detail='Bounded assumed-compromise fixture, same-process database misuse, reset and independently retained evidence.'),
    dict(name='CCC assessment & evaluation', status='Planned', detail='Verify catalog requirements, measure performance and false blocks. Supplier tests need its integration contract.'),
    dict(name='CVE remediation & OSERA VEX', status='Planned', detail='Compare a vulnerable fixture, upstream fix and OSERA backpatch with exact-artifact evidence and the same regression tests.'),
    dict(name='CALM follow-on state', status='Planned', detail='Separate state comparing manual and model-driven controls against the same tests; number undecided.'),
]


def now():
    return datetime.now(timezone.utc).isoformat()


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class Runner:
    def __init__(self, runtime):
        self.runtime = Path(runtime).resolve()
        self.runs = self.runtime / 'console-runs'
        self.runs.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.mutex = threading.Lock()
        self.active = None
        self.token = secrets.token_urlsafe(32)
        for path in self.runs.glob('*/run.json'):
            item = json.loads(path.read_text())
            if item['status'] == 'running':
                item.update(status='inconclusive', finished_at=now(), error='Runner interrupted; do not infer a result.')
                self.save(path.parent, item)

    def save(self, folder, item):
        temporary = folder / 'run.tmp'
        temporary.write_text(json.dumps(item, indent=2) + '\n')
        temporary.replace(folder / 'run.json')

    def summaries(self):
        items = [json.loads(p.read_text()) for p in self.runs.glob('*/run.json')]
        return sorted(items, key=lambda item: item['started_at'], reverse=True)[:50]

    def directory(self, run_id):
        if str(uuid.UUID(run_id)) != run_id:
            raise ValueError('Invalid run ID')
        folder = self.runs / run_id
        if not (folder / 'run.json').is_file():
            raise FileNotFoundError('Run not found')
        return folder

    def read(self, run_id, download=False):
        folder = self.directory(run_id)
        record = json.loads((folder / 'run.json').read_text())
        artifacts = {}
        for name in ['platform-result.json', 'waf-result.json', 'workloads-result.json', 'support-workloads-result.json', 'database-workload-result.json', 'collector-result.json', 'observability-result.json', 'database-permissions-result.json', 'nats-result.json']:
            path = folder / name
            # WAF harness writes into its evidence subdirectory.
            if not path.exists():
                path = folder / 'evidence' / name
            if path.exists():
                artifacts[name] = {'sha256': digest(path), 'data': json.loads(path.read_text())}
        log = folder / 'output.log'
        raw = log.read_text(errors='replace') if log.exists() else ''
        return {'run': record, 'log': raw if download else raw[-24000:], 'artifacts': artifacts,
                'log_sha256': digest(log) if log.exists() else None,
                'evidence_scope': 'Locally collected test evidence; not signed or tamper-proof compliance evidence.'}

    def command(self, scenario, folder):
        scripts = lab.ROOT / 'scripts/security-lab'
        if scenario == 'nats':
            return [sys.executable, str(scripts / 'verify_nats.py'), '--runtime-dir', str(self.runtime), '--output-dir', str(folder)]
        if scenario == 'sql':
            return [sys.executable, str(scripts / 'verify_database_permissions.py'), '--runtime-dir', str(self.runtime), '--output-dir', str(folder)]
        if scenario == 'observability':
            return [sys.executable, str(scripts / 'verify_workloads.py'), '--profile', 'observability', '--runtime-dir', str(self.runtime), '--output-dir', str(folder)]
        if scenario == 'collector':
            return [sys.executable, str(scripts / 'verify_collector.py'), '--runtime-dir', str(self.runtime), '--output-dir', str(folder)]
        if scenario == 'database':
            return [sys.executable, str(scripts / 'verify_workloads.py'), '--profile', 'database', '--runtime-dir', str(self.runtime), '--output-dir', str(folder)]
        if scenario == 'support':
            return [sys.executable, str(scripts / 'verify_workloads.py'), '--profile', 'support', '--runtime-dir', str(self.runtime), '--output-dir', str(folder)]
        if scenario == 'workloads':
            return [sys.executable, str(scripts / 'verify_workloads.py'), '--runtime-dir', str(self.runtime), '--output-dir', str(folder)]
        if scenario == 'platform':
            shutil.copyfile(lab.PROFILE / 'evidence/2026-11-22-platform-image.lock.json', folder / 'platform-image.lock.json')
            return [sys.executable, str(scripts / 'verify_platform.py'), '--kubeconfig',
                    str(self.runtime / 'kubeconfig'), '--output-dir', str(folder)]
        if scenario == 'waf':
            shutil.copyfile(lab.PROFILE / 'waf-images.lock.json', folder / 'waf-images.lock.json')
            return ['bash', str(scripts / 'run-waf.sh'), str(self.runtime), str(folder)]
        if scenario == 'baseline':
            return ['bash', str(scripts / 'test-reference.sh')]
        raise ValueError('Unknown scenario')

    def start(self, scenario):
        if scenario not in {s['id'] for s in SCENARIOS}:
            raise ValueError('Unknown scenario')
        with self.mutex:
            if self.active:
                raise BlockingIOError('Another experiment is running')
            lock = (self.runtime / 'console-run.lock').open('a')
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                lock.close()
                raise BlockingIOError('Another runner still owns an experiment')
            run_id = str(uuid.uuid4())
            folder = self.runs / run_id
            folder.mkdir(mode=0o700)
            source_files = list((lab.ROOT / 'scripts/security-lab').glob('*.py')) + list((lab.ROOT / 'scripts/security-lab').glob('*.sh'))
            source_files += list(lab.PROFILE.glob('*.json')) + [lab.ROOT / 'scripts/lib/kubernetes-smoke-readiness.sh']
            source_files += list((lab.ROOT / 'scripts').glob('test-*.sh'))
            record = dict(id=run_id, scenario=scenario, status='running', started_at=now(), finished_at=None,
                baseline=lab.read_json(lab.PROFILE / 'baseline.lock.json')['generated_commit'],
                source_hashes={str(p.relative_to(lab.ROOT)): digest(p) for p in source_files})
            self.save(folder, record)
            self.active = run_id
            threading.Thread(target=self.execute, args=(folder, record, lock), daemon=True).start()
            return record

    def execute(self, folder, record, lock):
        process = None
        try:
            record['mode'] = SCENARIO_MODES[record['scenario']]
            record['resource_preflight'] = check_resources(self.runtime, record['mode'])
            if record['resource_preflight']['status'] != 'ready':
                record.update(status='blocked', error='Capacity check blocked this run before execution: '+ ' '.join(record['resource_preflight']['reasons']))
                return
            command = self.command(record['scenario'], folder)
            env = dict(os.environ, TRADERX_SECURITY_RUNTIME=str(self.runtime), TRADERX_SECURITY_PYTHON=sys.executable, TRADERX_LAB_LOCK_FD=str(lock.fileno()))
            with (folder / 'output.log').open('w') as output:
                process = subprocess.Popen(command, cwd=lab.ROOT, env=env, stdout=output,
                    stderr=subprocess.STDOUT, start_new_session=True, pass_fds=(lock.fileno(),))
                try:
                    code = process.wait(timeout=RUN_TIMEOUT)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGTERM)
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        os.killpg(process.pid, signal.SIGKILL)
                        process.wait()
                    record.update(status='inconclusive', error='Experiment exceeded the 15 minute limit.')
                    code = process.returncode
                record['exit_code'] = code
                if record['status'] == 'running':
                    record['status'] = 'passed' if code == 0 else 'failed'
        except Exception as error:
            record.update(status='inconclusive', error=str(error))
        finally:
            record['finished_at'] = now()
            self.save(folder, record)
            lock.close()
            with self.mutex:
                self.active = None


def public_origin(value):
    parsed = urlsplit(value)
    if parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.password or parsed.path or parsed.query or parsed.fragment or parsed.netloc != parsed.hostname:
        raise argparse.ArgumentTypeError('Expected one HTTPS origin without path, port or credentials')
    return value


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def send(self, status, data, content_type='application/json', download=False):
        payload = json.dumps(data).encode() if content_type == 'application/json' else data
        self.send_response(status)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', str(len(payload)))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Referrer-Policy', 'no-referrer')
        policy = "default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'"
        if content_type == 'image/svg+xml':
            policy = "default-src 'none'; style-src 'unsafe-inline'; frame-ancestors 'none'"
        self.send_header('Content-Security-Policy', policy)
        if download:
            self.send_header('Content-Disposition', 'attachment; filename="security-lab-evidence.json"')
        self.end_headers()
        self.wfile.write(payload)

    def valid_host(self):
        port = self.server.server_address[1]
        allowed = [f'localhost:{port}', f'127.0.0.1:{port}']
        origin = getattr(self.server, 'public_origin', None)
        if origin: allowed.append(urlsplit(origin).netloc)
        return self.headers.get('Host') in allowed

    def do_GET(self):
        if not self.valid_host():
            return self.send(403, {'error': 'Local Host header required'})
        runner = self.server.runner
        try:
            if self.path == '/api/state':
                historical = []
                for name, scenario in [('2026-11-22-c3-baseline-result.json', 'baseline'),
                    ('2026-11-22-platform-result.json', 'platform'), ('2026-11-22-waf-result.json', 'waf')]:
                    data = lab.read_json(lab.PROFILE / 'evidence' / name)
                    historical.append({'scenario': scenario, 'status': data['status'], 'recorded_at': data.get('recorded_at', '2026-11-22'), 'scope': data.get('scope', 'Standalone WAF fixture')})
                return self.send(200, dict(scenarios=SCENARIOS, roadmap=ROADMAP, historical=historical,
                    runs=runner.summaries(), active=runner.active, csrf=runner.token))
            if self.path.startswith('/api/runs/'):
                parts = self.path.split('/')
                if len(parts) not in [4, 5] or (len(parts) == 5 and parts[4] != 'evidence'):
                    raise FileNotFoundError()
                download = len(parts) == 5
                return self.send(200, runner.read(parts[3], download), download=download)
            assets = {'/': ('index.html', 'text/html; charset=utf-8'),
                      '/app.js': ('app.js', 'text/javascript; charset=utf-8'),
                      '/style.css': ('style.css', 'text/css; charset=utf-8'),
                      '/traderx-logo.svg': (lab.ROOT / 'website/static/img/traderX/TraderX_Horizontal.svg', 'image/svg+xml'),
                      '/favicon.ico': (lab.ROOT / 'website/static/img/favicon/favicon-traderX.ico', 'image/x-icon')}
            if self.path in assets:
                file, kind = assets[self.path]
                return self.send(200, (UI / file).read_bytes(), kind)
            raise FileNotFoundError()
        except (ValueError, FileNotFoundError):
            self.send(404, {'error': 'Not found'})

    def do_POST(self):
        port = self.server.server_address[1]
        public = getattr(self.server, 'public_origin', None)
        remote = public and self.headers.get('Host') == urlsplit(public).netloc
        expected_origin = public if remote else f'http://{self.headers.get("Host")}'
        origin = self.headers.get('Origin', '' if remote else expected_origin)
        if not self.valid_host() or origin != expected_origin:
            return self.send(403, {'error': 'Same-origin request required'})
        if not secrets.compare_digest(self.headers.get('X-Lab-CSRF', ''), self.server.runner.token):
            return self.send(403, {'error': 'Invalid request token'})
        if self.path != '/api/runs':
            return self.send(404, {'error': 'Not found'})
        if self.headers.get('Content-Type') != 'application/json':
            return self.send(415, {'error': 'JSON required'})
        try:
            size = int(self.headers.get('Content-Length', '0'))
            if not 1 <= size <= 256:
                raise ValueError('Invalid request size')
            data = json.loads(self.rfile.read(size))
            if not isinstance(data, dict) or set(data) != {'scenario'} or not isinstance(data['scenario'], str):
                raise ValueError('Only a scenario ID is accepted')
            record = self.server.runner.start(data['scenario'])
            self.send(202, record)
        except BlockingIOError as error:
            self.send(409, {'error': str(error)})
        except (ValueError, TypeError) as error:
            self.send(400, {'error': str(error)})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-dir', type=Path, default=Path('/private/tmp/traderx-security-runtime'))
    parser.add_argument('--port', type=int, default=18081)
    parser.add_argument('--public-origin', type=public_origin, help='Exact HTTPS origin; requires an authenticated tunnel in front of the loopback listener')
    args = parser.parse_args()
    server = ThreadingHTTPServer(('127.0.0.1', args.port), Handler)
    server.runner = Runner(args.runtime_dir)
    server.public_origin = args.public_origin
    print(f'Security Lab console: http://127.0.0.1:{args.port}', flush=True)
    server.serve_forever()


if __name__ == '__main__':
    main()
