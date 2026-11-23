#!/usr/bin/env python3
"""Compare Coraza modes over verified local TLS against a harmless recording backend."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import ssl
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

LABEL = 'traderx.security-lab.waf'
NETWORK = 'traderx-security-waf-check'
EDGE_NETWORK = 'traderx-security-waf-edge'
PROXY = 'traderx-security-waf-proxy'
BACKEND = 'traderx-security-waf-backend'

BACKEND_CODE = '''import http.server,json
class Handler(http.server.BaseHTTPRequestHandler):
 def do_GET(self):
  self.rfile.read(int(self.headers.get('Content-Length','0')))
  print(json.dumps({'run_id':self.headers.get('X-Lab-Run'),'received':True}),flush=True)
  self.send_response(200);self.end_headers();self.wfile.write(b'fixture-ok')
 do_POST=do_GET
 def log_message(self,*args): pass
http.server.HTTPServer(('0.0.0.0',8080),Handler).serve_forever()
'''


def envoy_config(mode):
    if mode not in ['Off', 'DetectionOnly', 'On']:
        raise ValueError('Unsupported WAF mode')
    directives = ['Include @demo-conf', 'Include @crs-setup-conf',
                  'SecDebugLogLevel 3', 'SecRuleEngine ' + mode, 'Include @owasp_crs/*.conf']
    wasm = {'name': 'envoy.filters.http.wasm', 'typed_config': {
        '@type': 'type.googleapis.com/envoy.extensions.filters.http.wasm.v3.Wasm',
        'config': {'name': 'coraza-filter', 'configuration': {
            '@type': 'type.googleapis.com/google.protobuf.StringValue',
            'value': json.dumps({'directives_map': {'default': directives}, 'default_directives': 'default'})},
            'vm_config': {'runtime': 'envoy.wasm.runtime.v8', 'vm_id': 'coraza',
                          'code': {'local': {'filename': '/etc/envoy/coraza.wasm'}}}}}}
    manager = {'@type': 'type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager',
        'stat_prefix': 'lab', 'codec_type': 'AUTO',
        'route_config': {'name': 'lab', 'virtual_hosts': [{'name': 'fixture', 'domains': ['*'],
            'routes': [{'match': {'prefix': '/'}, 'route': {'cluster': 'fixture'}}]}]},
        'http_filters': [wasm, {'name': 'envoy.filters.http.router', 'typed_config': {
            '@type': 'type.googleapis.com/envoy.extensions.filters.http.router.v3.Router'}}]}
    return {'static_resources': {
        'listeners': [{'name': 'tls', 'address': {'socket_address': {'address': '0.0.0.0', 'port_value': 8443}},
            'filter_chains': [{'transport_socket': {'name': 'envoy.transport_sockets.tls', 'typed_config': {
                '@type': 'type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.DownstreamTlsContext',
                'common_tls_context': {'tls_certificates': [{'certificate_chain': {'filename': '/lab/cert.pem'},
                    'private_key': {'filename': '/lab/key.pem'}}]}}},
                'filters': [{'name': 'envoy.filters.network.http_connection_manager', 'typed_config': manager}]}]}],
        'clusters': [{'name': 'fixture', 'connect_timeout': '2s', 'type': 'STRICT_DNS',
            'load_assignment': {'cluster_name': 'fixture', 'endpoints': [{'lb_endpoints': [{'endpoint': {
                'address': {'socket_address': {'address': BACKEND, 'port_value': 8080}}}}]}]}}]}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-dir', type=Path, required=True)
    args = parser.parse_args()
    root = args.runtime_dir.resolve()
    lock = json.loads((root / 'waf-images.lock.json').read_text())
    evidence = root / 'evidence'
    evidence.mkdir(exist_ok=True)
    configdir = root / 'waf-config'
    configdir.mkdir(mode=0o700, exist_ok=True)
    (configdir / 'backend.py').write_text(BACKEND_CODE)
    docker = ['docker', '--config', str(root / 'docker-client'), '--host',
              'unix://' + str(Path.home() / '.docker/run/docker.sock')]

    def run(*argv, required=True):
        result = subprocess.run(docker + list(argv), capture_output=True, text=True, timeout=120)
        if required and result.returncode:
            raise RuntimeError(result.stderr)
        return result

    def remove_owned(name):
        found = run('inspect', name, required=False)
        if found.returncode:
            return
        if json.loads(found.stdout)[0]['Config'].get('Labels', {}).get(LABEL) != 'true':
            raise ValueError(f'Refusing to replace unrelated container {name}')
        run('rm', '-f', name)

    existing = run('network', 'inspect', NETWORK, required=False)
    if existing.returncode:
        run('network', 'create', '--internal', '--label', LABEL + '=true', NETWORK)
    elif json.loads(existing.stdout)[0].get('Labels', {}).get(LABEL) != 'true':
        raise ValueError('Refusing to use unrelated Docker network')
    existing_edge = run('network', 'inspect', EDGE_NETWORK, required=False)
    if existing_edge.returncode:
        run('network', 'create', '--label', LABEL + '=true', EDGE_NETWORK)
    elif json.loads(existing_edge.stdout)[0].get('Labels', {}).get(LABEL) != 'true':
        raise ValueError('Refusing to use unrelated Docker edge network')
    if not (configdir / 'cert.pem').exists():
        subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes',
            '-keyout', str(configdir / 'key.pem'), '-out', str(configdir / 'cert.pem'),
            '-days', '2', '-subj', '/CN=localhost', '-addext', 'subjectAltName=DNS:localhost,IP:127.0.0.1'],
            check=True, capture_output=True, timeout=20)
        # Parent directory remains private; the read-only container mount permits the unprivileged proxy to read its test key.
        (configdir / 'key.pem').chmod(0o644)
    context = ssl.create_default_context(cafile=str(configdir / 'cert.pem'))
    common = ['--network', NETWORK, '--label', LABEL + '=true', '--read-only', '--cap-drop', 'ALL',
              '--security-opt', 'no-new-privileges', '--user', '65532:65532',
              '--mount', f'type=bind,src={configdir},dst=/lab,readonly']
    results = []
    image_id = run('image', 'inspect', 'traderx-security-waf:coraza-0.6.0-envoy-1.40.2',
                   '--format', '{{.Id}}').stdout.strip()

    def request(run_id, path='/', data=None):
        headers = {'X-Lab-Run': run_id}
        if data is not None:
            headers['Content-Type'] = 'application/json'
        req = urllib.request.Request('https://localhost:18443' + path, data=data, headers=headers)
        try:
            with urllib.request.urlopen(req, context=context, timeout=5) as response:
                return response.status, response.read().decode()
        except urllib.error.HTTPError as error:
            return error.code, error.read().decode()

    try:
        remove_owned(BACKEND)
        run('run', '-d', '--name', BACKEND, *common, '--memory', '64m', lock['backend']['image'], 'python', '-u', '/lab/backend.py')
        for mode in ['Off', 'DetectionOnly', 'On']:
            remove_owned(PROXY)
            config = json.dumps(envoy_config(mode), sort_keys=True)
            (configdir / 'envoy.json').write_text(config)
            proxy_common = [EDGE_NETWORK if arg == NETWORK else arg for arg in common]
            run('run', '-d', '--name', PROXY, *proxy_common, '--memory', '512m',
                '-p', '127.0.0.1:18443:8443', image_id,
                '-c', '/lab/envoy.json', '--concurrency', '1', '--log-level', 'info')
            run('network', 'connect', NETWORK, PROXY)
            for _ in range(30):
                try:
                    if request('warmup')[0] == 200:
                        break
                except (OSError, urllib.error.URLError):
                    pass
                time.sleep(1)
            else:
                raise RuntimeError('WAF did not become ready: ' + run('logs', PROXY).stderr[-2000:])
            cases = []
            for name, path, data in [
                ('benign', '/?symbol=IBM', None),
                ('sql-query', '/?' + urllib.parse.urlencode({'id': "1' OR '1'='1"}), None),
                ('sql-json', '/', json.dumps({'id': "1' OR '1'='1"}).encode()),
                ('benign-after', '/?symbol=AAPL', None),
            ]:
                run_id = str(uuid.uuid4())
                status, body = request(run_id, path, data)
                logs = run('logs', BACKEND)
                received = any(json.loads(line).get('run_id') == run_id for line in logs.stdout.splitlines() if line.startswith('{'))
                expected = 403 if mode == 'On' and name.startswith('sql-') else 200
                cases.append({'case': name, 'run_id': run_id, 'http_status': status,
                              'backend_received': received, 'expected_status': expected,
                              'passed': status == expected and received == (expected == 200)})
            logs = run('logs', PROXY)
            log_text = logs.stdout + logs.stderr
            (evidence / f'waf-{mode}.log').write_text(log_text)
            rule_ids = sorted(set(re.findall(r'\[id "(\d+)"\]', log_text)))
            detected = any(rule.startswith('942') for rule in rule_ids)
            results.append({'mode': mode, 'cases': cases, 'sql_rule_detected': detected,
                'rule_ids': rule_ids, 'config_sha256': hashlib.sha256(config.encode()).hexdigest(),
                'passed': all(case['passed'] for case in cases) and (mode == 'Off' or detected)})
            print(mode, results[-1]['passed'], flush=True)
        record = {'status': 'passed' if all(r['passed'] for r in results) else 'failed',
            'recorded_at': datetime.now(timezone.utc).isoformat(), 'image_id': image_id, 'pins': lock,
            'tls_verified': True, 'results': results,
            'limitations': ['Harmless recording backend; no verified exploit or TraderX RCE claim',
                           'Standalone Envoy proxy-Wasm compatibility, not Envoy Gateway integration',
                           'Reference C3 is not routed through this fixture; full hardening remains pending']}
        (evidence / 'waf-result.json').write_text(json.dumps(record, indent=2) + '\n')
        if record['status'] != 'passed':
            raise RuntimeError('WAF comparison did not meet expected evidence; inspect waf-result.json')
    finally:
        # Keep evidence on the host; stop ephemeral fixtures to return memory to C3.
        for name in [PROXY, BACKEND]:
            remove_owned(name)


if __name__ == '__main__':
    main()
