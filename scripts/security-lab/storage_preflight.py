"""Fail closed on node disk capacity before Loki's WAL write throttle is reached."""
from pathlib import Path
import subprocess
from cluster_identity import selected

RESERVE_BYTES=2*1024**3
MAX_USED_PERCENT=85  # Margin below Loki's 90% WAL throttle; never disable it.


def observe(output):
    lines=output.strip().splitlines()
    if len(lines)!=2:raise ValueError('Unrecognized node filesystem observation')
    columns=lines[1].split()
    if len(columns)!=6 or not all(c.isdigit() for c in columns[1:4]):
        raise ValueError('Unrecognized node filesystem observation')
    total,used,available=(int(c)*1024 for c in columns[1:4])
    if total<=0 or used+available>total:raise ValueError('Inconsistent node filesystem observation')
    return {'total_bytes':total,'used_bytes':used,'available_bytes':available,
            'used_percent':100*used/total}


def available_bytes(output):
    return observe(output)['available_bytes']


def checks(observation):
    return {'node_disk_reserve':observation['available_bytes']>=RESERVE_BYTES,
            'node_disk_usage_margin':100*observation['used_bytes']<MAX_USED_PERCENT*observation['total_bytes']}


def require(output):
    observation=observe(output)
    if not all(checks(observation).values()):
        raise RuntimeError('Node disk needs at least 2 GiB available and usage below 85% (Loki throttles at 90%); preserve data and explicitly free space or increase disk capacity')
    return observation['available_bytes']


def require_node(runtime):
    command=['docker','--config',str(Path(runtime)/'docker-client'),'--host','unix://'+str(Path.home()/'.docker/run/docker.sock'),
             'exec',selected(runtime)+'-control-plane','df','-Pk','/var/lib/containerd']
    return require(subprocess.run(command,check=True,capture_output=True,text=True,timeout=15).stdout)
