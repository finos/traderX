"""Explicit supported cluster selection; existing runtimes retain the original default."""
import json
from pathlib import Path

DEFAULT='traderx-security-lab'
VALIDATION='traderx-security-lab-validation'
CHOICES=(DEFAULT,VALIDATION)


def selected(runtime):
    path=Path(runtime)/'cluster-selection.json'
    if not path.exists() and not path.is_symlink():return DEFAULT
    if path.is_symlink() or not path.is_file():raise ValueError('Invalid cluster selection file')
    data=json.loads(path.read_text())
    if set(data)!={'cluster'} or data['cluster'] not in CHOICES:raise ValueError('Unreviewed cluster selection')
    return data['cluster']


def record(runtime,name):
    if name not in CHOICES:raise ValueError('Unreviewed cluster name')
    path=Path(runtime)/'cluster-selection.json'
    with path.open('x') as target:json.dump({'cluster':name},target);target.write('\n')
    path.chmod(0o600)
