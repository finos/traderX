#!/usr/bin/env python3
"""Keep the independently audited Sail graph immutable during state generation."""
import argparse
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
RELATIVE = Path('fdc3-intent-interoperability/sail/bootstrap/dependency-overlay')
CANONICAL = ROOT / 'specs/014-fdc3-intent-interoperability/generation/sail-dependencies'


def validate(root, targets):
    overlay = root / RELATIVE
    if not overlay.exists():
        if (root / 'fdc3-intent-interoperability/sail').is_dir():
            raise ValueError('missing frozen Sail dependency overlay')
        return False
    policy = json.loads(targets.read_text())['npm']['sail']
    if json.loads((overlay / 'policy.json').read_text()) != policy:
        raise ValueError('generated Sail dependency policy differs from central targets')
    pin = (ROOT / 'specs/014-fdc3-intent-interoperability/generation/sail-pin.env').read_text()
    commit = re.search(r'^SAIL_PIN_REPO_COMMIT="([0-9a-f]{40})"$', pin, re.M)
    if not commit or commit[1] != policy['sourceCommit']:
        raise ValueError('Sail source pin differs from dependency overlay guard')
    expected = set(policy['files']) | {'apply.cjs', 'policy.json'}
    actual = {p.relative_to(overlay).as_posix() for p in overlay.rglob('*') if p.is_file()}
    if actual != expected:
        raise ValueError('generated Sail dependency overlay file inventory differs')
    for name in expected - {'policy.json'}:
        if (overlay / name).read_bytes() != (CANONICAL / name).read_bytes():
            raise ValueError(f'generated Sail dependency overlay changed: {name}')
    return True


if __name__ == '__main__':
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--targets', type=Path, required=True)
    parser.add_argument('roots', type=Path, nargs='+')
    args = parser.parse_args()
    count = sum(validate(root, args.targets) for root in args.roots)
    print(f'[ok] frozen Sail dependency overlays validated ({count})')
