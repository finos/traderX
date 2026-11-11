#!/usr/bin/env python3
"""Read-only demo diagnosis. Never dump container environments or proxy credentials."""
import json
from pathlib import Path
import urllib.request
import urllib.parse
import re
import subprocess


def command(*args):
    try:
        p = subprocess.run(args, capture_output=True, text=True, timeout=30)
        return {'exit_code': p.returncode, 'stdout': p.stdout, 'stderr': p.stderr}
    except (OSError, subprocess.SubprocessError) as exc:
        return {'error': str(exc)}


def main():
    report = {'compose': command('docker', 'compose', 'ls', '--format', 'json'),
              'containers': command('docker', 'ps', '-a', '--format', '{{json .}}'),
              'volumes': command('docker', 'volume', 'ls', '--format', '{{json .}}'),
              'disk': command('df', '-h', '/'),
              'docker_disk': command('docker', 'system', 'df'),
              'memory': command('free', '-m'),
              'nginx_test': command('sudo', '-n', 'nginx', '-t')}
    ids = command('docker', 'ps', '-aq').get('stdout', '').split()
    report['postgres'] = {}
    report['runtime'] = []
    for cid in ids:
        data = command('docker', 'inspect', cid)
        if data.get('exit_code') != 0:
            continue
        item = json.loads(data['stdout'])[0]
        labels = item.get('Config', {}).get('Labels') or {}
        report['runtime'].append({'name': item['Name'], 'image': item['Config']['Image'],
            'status': item['State']['Status'], 'exit_code': item['State']['ExitCode'],
            'oom_killed': item['State']['OOMKilled'],
            'health': item['State'].get('Health', {}).get('Status'),
            'project': labels.get('com.docker.compose.project'),
            'service': labels.get('com.docker.compose.service'),
            'working_dir': labels.get('com.docker.compose.project.working_dir'),
            'mounts': [{k: m.get(k) for k in ('Type', 'Name', 'Source', 'Destination')}
                       for m in item.get('Mounts', [])]})
    databases = [r for r in report['runtime']
                 if r['project'] == 'traderx-009-order-management-matcher' and r['service'] == 'database']
    if len(databases) == 1:
        mounts = [m for m in databases[0]['mounts']
                  if m['Type'] == 'volume' and m['Destination'] == '/var/lib/postgresql/data']
        if len(mounts) == 1:
            volume = mounts[0]['Name']
            volume_data = command('docker', 'volume', 'inspect', volume)
            if volume_data.get('exit_code') == 0:
                mount = json.loads(volume_data['stdout'])[0]['Mountpoint']
                report['postgres'] = {'volume': volume,
                    'version': command('sudo', '-n', 'cat', mount + '/PG_VERSION'),
                    'size': command('sudo', '-n', 'du', '-sb', mount)}
    config = command('sudo', '-n', 'nginx', '-T').get('stdout', '')
    report['proxy_routes'] = [re.sub(r'(https?://)[^/\s@]+@', r'\1[redacted]@', line.strip())
                              for line in config.splitlines()
                              if re.match(r'^\s*(server_name|listen|proxy_pass)\s', line)]
    report['http'] = {}
    for path in ('/', '/trade-service/system/health', '/order-matcher/system/health', '/grafana/api/health'):
        report['http'][path] = command('curl', '-sS', '-o', '/dev/null', '-w', '%{http_code}',
                                      '--max-time', '10', 'http://127.0.0.1:8080' + path)
    report['observability'] = {}
    for name, port, path in [('grafana', 3001, '/api/health'), ('prometheus', 9090, '/-/ready'),
                             ('loki', 3100, '/ready'), ('tempo', 3200, '/ready')]:
        report['observability'][name] = command('curl', '-sS', '-o', '/dev/null', '-w', '%{http_code}',
                                               '--max-time', '10', f'http://127.0.0.1:{port}{path}')
    try:
        query = urllib.parse.urlencode({'query': '{compose_project="traderx-009-order-management-matcher"}', 'limit': '1'})
        with urllib.request.urlopen('http://127.0.0.1:3100/loki/api/v1/query_range?' + query, timeout=10) as response:
            logs = json.load(response)
        report['log_query'] = {'status': logs['status'], 'streams': len(logs['data']['result'])}
    except Exception as exc:
        report['log_query'] = {'error': str(exc)}
    try:
        with urllib.request.urlopen('http://127.0.0.1:3200/api/search?limit=1', timeout=10) as response:
            traces = json.load(response)
        report['trace_query'] = {'traces': len(traces.get('traces', []))}
    except Exception as exc:
        report['trace_query'] = {'error': str(exc)}
    audit = Path.home() / 'traderx/.traderx-deploy'
    for name in ['deployed.json', 'recovery-image-cache.json']:
        if (audit / name).is_file():
            report[name] = json.loads((audit / name).read_text())
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
