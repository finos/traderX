#!/usr/bin/env python3
"""Read-only capacity checks. Never changes Docker settings or starts/stops workloads."""
import argparse
import json
import math
from pathlib import Path
import platform
import re
import subprocess

GIB = 1024 ** 3
LAB = 'traderx-security-lab-control-plane'
# Provisional operating margins, not measured application minimum requirements.
RESERVE = {'development': 1.5 * GIB, 'build': 2 * GIB, 'fixture': 1.5 * GIB, 'acceptance': .75 * GIB}


def memory_bytes(text):
    match = re.fullmatch(r'\s*([0-9]+(?:\.[0-9]+)?)\s*(B|kB|KB|KiB|MB|MiB|GB|GiB|TB|TiB)\s*', text)
    if not match:
        raise ValueError('Unknown Docker memory unit')
    units = {'B': 1, 'kB': 1000, 'KB': 1000, 'KiB': 1024, 'MB': 1000**2,
             'MiB': 1024**2, 'GB': 1000**3, 'GiB': GIB, 'TB': 1000**4, 'TiB': 1024**4}
    return int(float(match[1]) * units[match[2]])


def assess(snapshot, mode):
    if mode not in RESERVE:
        raise ValueError('Unknown operating mode')
    reasons = []
    if snapshot['host_pressure'] not in ('normal',):
        reasons.append('Host memory pressure is elevated or unavailable.')
    containers = snapshot['containers']
    total = snapshot['docker_memory_bytes']
    values = [c['memory_bytes'] for c in containers]
    if not isinstance(total, (int, float)) or not math.isfinite(total) or total <= 0 or any(
            not isinstance(v, (int, float)) or not math.isfinite(v) or v < 0 for v in values):
        raise ValueError('Invalid capacity observation')
    if total - sum(values) < RESERVE[mode]:
        reasons.append('Insufficient Docker headroom for the provisional operating margin.')
    if mode in ('development', 'fixture', 'build') and any(c['name'].endswith('-control-plane') for c in containers):
        reasons.append(mode.capitalize()+' mode requires Kubernetes labs stopped; use an explicit sequential workflow.')
    if mode == 'acceptance' and LAB not in {c['name'] for c in containers}:
        reasons.append('Full acceptance requires the security-lab control plane running.')
    if any(c['name'].endswith('-control-plane') and c['name'] != LAB for c in containers):
        reasons.append('Another Kubernetes lab is running.')
    if mode == 'acceptance' and any(c['name'].startswith('traderx-account-dev-') for c in containers):
        reasons.append('Stop the account development environment before full acceptance.')
    return {'status': 'blocked' if reasons else 'ready', 'mode': mode, 'reasons': reasons,
            'required_headroom_bytes': int(RESERVE[mode]), 'observation': snapshot,
            'limitations': ['Snapshot only; not a reservation or a guarantee against subsequent pressure.',
                           'Docker container working sets omit some VM/kernel overhead; margins are provisional.',
                           'Readiness does not establish application health or security acceptance.']}


def observe(runtime):
    def run(command):
        return subprocess.run(command, capture_output=True, text=True, check=True, timeout=15).stdout
    pressure = 'unknown'
    if platform.system() == 'Darwin':
        level = int(run(['sysctl', '-n', 'kern.memorystatus_vm_pressure_level']).strip())
        pressure = 'normal' if level == 1 else 'elevated'
    docker = ['docker', '--config', str(runtime/'docker-client'), '--host',
              'unix://'+str(Path.home()/'.docker/run/docker.sock')]
    total = int(run(docker+['info', '--format', '{{.MemTotal}}']).strip())
    rows = run(docker+['stats', '--no-stream', '--format', '{{json .}}']).splitlines()
    containers = []
    for row in rows:
        item = json.loads(row)
        containers.append({'name': item['Name'], 'memory_bytes': memory_bytes(item['MemUsage'].split('/')[0])})
    return {'host_pressure': pressure, 'docker_memory_bytes': total, 'containers': containers}


def check(runtime, mode):
    try:
        return assess(observe(runtime), mode)
    except (OSError, subprocess.SubprocessError, ValueError, KeyError, TypeError) as error:
        return {'status': 'blocked', 'mode': mode,
                'reasons': ['Capacity observation unavailable: '+type(error).__name__]}


def require(runtime, mode):
    result = check(runtime, mode)
    if result['status'] != 'ready':
        raise RuntimeError('Resource preflight: '+' '.join(result['reasons']))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-dir', type=Path, default=Path('/private/tmp/traderx-security-runtime'))
    parser.add_argument('--mode', choices=RESERVE, required=True)
    args = parser.parse_args()
    result = check(args.runtime_dir, args.mode)
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if result['status'] == 'ready' else 2)


if __name__ == '__main__': main()
