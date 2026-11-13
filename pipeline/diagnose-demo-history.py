#!/usr/bin/env python3
"""Collect bounded, structured demo diagnostics without exporting raw logs."""
import datetime as dt
import json
import os
import re
import subprocess
from pathlib import Path

PROJECTS = {
    'traderx-004-containerized-compose-runtime',
    'traderx-009-order-management-matcher',
    'traderx-004-containerized-compose-runtime-ghcr',
    'traderx-009-order-management-matcher-ghcr',
    'traderx-state-004',
    'traderx-state-009',
}
SERVICES = {
    'ingress', 'web-front-end-angular', 'trade-service', 'reference-data',
    'account-service', 'trade-processor', 'position-service', 'database',
    'trade-feed', 'people-service', 'order-matcher', 'grafana', 'prometheus',
    'price-publisher', 'promtail', 'otel-collector', 'blackbox-exporter',
    'loki', 'tempo', 'nats-broker',
}
EVENTS = {'start', 'die', 'oom', 'restart', 'stop', 'kill'}


def command(*args):
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.SubprocessError):
        return None, 'unavailable'
    if result.returncode:
        return None, 'command_failed'
    return result.stdout, None


def identity(labels):
    project = labels.get('com.docker.compose.project')
    service = labels.get('com.docker.compose.service')
    if project in PROJECTS and service in SERVICES:
        return project, service
    return None


def container_summary():
    ids, error = command('docker', 'ps', '-aq', '--no-trunc')
    if error:
        return {'error': error}
    ids = ids.split()
    if not ids:
        return {'containers': []}
    raw, error = command('docker', 'inspect', *ids)
    if error:
        return {'error': error}
    try:
        result = []
        for item in json.loads(raw):
            name = identity(item.get('Config', {}).get('Labels') or {})
            if not name:
                continue
            state = item['State']
            health = (state.get('Health') or {}).get('Status')
            result.append({'project': name[0], 'service': name[1],
                           'status': state['Status'] if state['Status'] in
                           {'created', 'restarting', 'running', 'removing', 'paused', 'exited', 'dead'} else 'unknown',
                           'exit_code': int(state['ExitCode']),
                           'oom_killed': bool(state['OOMKilled']),
                           'restart_count': int(item['RestartCount']),
                           'health': health if health in {'starting', 'healthy', 'unhealthy'} else None})
        return {'containers': result}
    except (KeyError, TypeError, ValueError):
        return {'error': 'invalid_container_data'}


def docker_events():
    raw, error = command('docker', 'events', '--since', '168h', '--until', '0s', '--format', '{{json .}}')
    if error:
        return {'error': error}
    events = []
    try:
        for line in raw.splitlines():
            event = json.loads(line)
            action = event.get('Action')
            name = identity(event.get('Actor', {}).get('Attributes', {}))
            if event.get('Type') == 'container' and action in EVENTS and name:
                timestamp = event.get('time')
                if isinstance(timestamp, int):
                    events.append({'time': dt.datetime.fromtimestamp(timestamp, dt.timezone.utc).isoformat(),
                                   'project': name[0], 'service': name[1], 'event': action})
        return {'events': events, 'note': 'Docker may retain only recent events, especially after daemon restart.'}
    except (TypeError, ValueError, OverflowError, OSError):
        return {'error': 'invalid_event_data'}


def kernel_oom():
    raw, error = command('journalctl', '_TRANSPORT=kernel', '--since', '7 days ago', '-n', '5000', '-o', 'json', '--no-pager')
    if error:
        return {'error': error}
    count = 0
    timestamps = []
    try:
        for line in raw.splitlines():
            entry = json.loads(line)
            message = entry.get('MESSAGE', '')
            if isinstance(message, str) and re.search(r'out of memory|oom-kill|killed process', message, re.I):
                count += 1
                timestamp = entry.get('__REALTIME_TIMESTAMP', '')
                if isinstance(timestamp, str) and re.fullmatch(r'[0-9]{1,18}', timestamp):
                    timestamps.append(dt.datetime.fromtimestamp(int(timestamp) / 1000000, dt.timezone.utc).isoformat())
        return {'matching_entries': count, 'timestamps': timestamps,
                'note': 'Limited to the last 5000 kernel journal entries.'}
    except (TypeError, ValueError, OverflowError, OSError):
        return {'error': 'invalid_journal_data'}


def boot_history():
    raw, error = command('journalctl', '--list-boots', '--no-pager')
    if error:
        return {'error': error}
    boots = []
    for line in raw.splitlines():
        match = re.match(r'\s*(-?\d+)\s+[0-9a-f]{32}\s+\w+\s+'
                         r'(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\s+[A-Za-z0-9_+:/-]+\s*—\s*'
                         r'\w+\s+(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\s+[A-Za-z0-9_+:/-]+\s*$', line)
        if match:
            boots.append({'index': int(match.group(1)), 'first_local': match.group(2), 'last_local': match.group(3)})
    return {'boots': boots[-20:], 'note': 'Boot timestamps use the host local timezone.'}


def service_journal():
    raw, error = command('journalctl', '--since', '7 days ago', '-n', '5000', '-o', 'json',
                         '--no-pager', '-u', 'docker', '-u', 'nginx', '-u', 'crond', '-u', 'cron')
    if error:
        return {'error': error}
    units = {'docker.service', 'nginx.service', 'crond.service', 'cron.service'}
    result = {unit: {'entries': 0, 'warning_or_error_timestamps': []} for unit in sorted(units)}
    try:
        for line in raw.splitlines():
            item = json.loads(line)
            unit = item.get('_SYSTEMD_UNIT')
            if unit not in units:
                unit = item.get('UNIT')
            if unit not in units:
                continue
            result[unit]['entries'] += 1
            priority = item.get('PRIORITY')
            timestamp = item.get('__REALTIME_TIMESTAMP')
            if (priority in {'0', '1', '2', '3', '4'} and isinstance(timestamp, str)
                    and re.fullmatch(r'[0-9]{1,18}', timestamp)):
                result[unit]['warning_or_error_timestamps'].append(
                    dt.datetime.fromtimestamp(int(timestamp) / 1000000, dt.timezone.utc).isoformat())
        return {'units': result, 'note': 'Limited to the last 5000 entries; no messages are exported.'}
    except (TypeError, ValueError, OverflowError, OSError):
        return {'error': 'invalid_journal_data'}


def http_status(port, path):
    raw, error = command('curl', '-sS', '-o', '/dev/null', '-w', '%{http_code}',
                         '--max-time', '10', 'http://127.0.0.1:' + str(port) + path)
    if error:
        return {'error': error}
    return {'status': int(raw)} if re.fullmatch(r'[1-5][0-9]{2}', raw) else {'error': 'invalid_response'}


def scheduling_summary():
    raw, error = command('systemctl', 'list-timers', '--all', '--no-pager', '--plain')
    if error:
        return {'error': error}
    timers = set(re.findall(r'\btraderx[-a-z0-9_.]*\.timer\b', raw))
    return {'traderx_timer_count': len(timers)}


def resources():
    disk = os.statvfs('/')
    memory = {}
    try:
        for line in Path('/proc/meminfo').read_text().splitlines():
            match = re.fullmatch(r'(MemTotal|MemAvailable|SwapTotal|SwapFree):\s+([0-9]+)\s+kB', line)
            if match:
                memory[match.group(1)] = int(match.group(2))
    except OSError:
        memory = {'error': 'unavailable'}
    return {'disk_total_bytes': disk.f_blocks * disk.f_frsize,
            'disk_available_bytes': disk.f_bavail * disk.f_frsize, 'memory_kib': memory}


def main():
    report = {'generated_at': dt.datetime.now(dt.timezone.utc).isoformat(),
              'runtime': container_summary(), 'docker_events': docker_events(),
              'kernel_oom': kernel_oom(), 'boot_history': boot_history(),
              'service_journal': service_journal(),
              'scheduling': scheduling_summary(),
              'resources': resources(),
              'http': {path: http_status(8080, path) for path in
                       ('/', '/health', '/trade-service/system/health', '/order-matcher/system/health', '/grafana/api/health')}}
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
