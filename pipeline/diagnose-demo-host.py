#!/usr/bin/env python3
"""Read-only demo diagnosis. Never dump container environments or proxy credentials."""
import json
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
              'nginx_test': command('sudo', '-n', 'nginx', '-t')}
    ids = command('docker', 'ps', '-aq').get('stdout', '').split()
    report['postgres'] = {}
    volume = 'traderx-009-order-management-matcher_postgres_state_009_data'
    volume_data = command('docker', 'volume', 'inspect', volume)
    if volume_data.get('exit_code') == 0:
        mount = json.loads(volume_data['stdout'])[0]['Mountpoint']
        report['postgres'] = {'volume': volume,
            'version': command('sudo', '-n', 'cat', mount + '/PG_VERSION'),
            'size': command('sudo', '-n', 'du', '-sb', mount)}
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
            'project': labels.get('com.docker.compose.project'),
            'service': labels.get('com.docker.compose.service'),
            'working_dir': labels.get('com.docker.compose.project.working_dir'),
            'mounts': [{k: m.get(k) for k in ('Type', 'Name', 'Source', 'Destination')}
                       for m in item.get('Mounts', [])]})
    config = command('sudo', '-n', 'nginx', '-T').get('stdout', '')
    report['proxy_routes'] = [re.sub(r'(https?://)[^/\s@]+@', r'\1[redacted]@', line.strip())
                              for line in config.splitlines()
                              if re.match(r'^\s*(server_name|listen|proxy_pass)\s', line)]
    report['http'] = {}
    for path in ('/', '/trade-service/system/health', '/order-matcher/system/health', '/grafana/api/health'):
        report['http'][path] = command('curl', '-sS', '-o', '/dev/null', '-w', '%{http_code}',
                                      '--max-time', '10', 'http://127.0.0.1:8080' + path)
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
