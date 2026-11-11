#!/usr/bin/env python3
"""Reject stale vulnerable npm resolutions after an override has been retired."""
import argparse
import json
from pathlib import Path
import re
import sys


def version(value):
    if not isinstance(value, str) or not re.fullmatch(r'\d+\.\d+\.\d+(?:\+[\w.-]+)?', value):
        raise ValueError(f'expected stable npm version, found {value!r}')
    return tuple(int(part) for part in value.split('+', 1)[0].split('.'))


def validate(lock, minimums):
    packages = lock.get('packages')
    if not isinstance(packages, dict):
        raise ValueError('npm lockfile must contain the resolved packages map')
    for path, package in packages.items():
        for name, minimum in minimums.items():
            if path == 'node_modules/' + name or path.endswith('/node_modules/' + name):
                if version(package.get('version')) < version(minimum):
                    raise ValueError(f'{path} resolves {package.get("version")}, below required {minimum}')


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--targets', type=Path, required=True)
    parser.add_argument('roots', type=Path, nargs='+')
    args = parser.parse_args()
    minimums = json.loads(args.targets.read_text()).get('npm', {}).get('resolvedMinimums', {})
    for value in minimums.values():
        version(value)
    count = 0
    for root in args.roots:
        for lockfile in root.rglob('package-lock.json'):
            if any(part in ('node_modules', 'runtime-cache', '.git') for part in lockfile.relative_to(root).parts):
                continue
            try:
                validate(json.loads(lockfile.read_text()), minimums)
            except (ValueError, TypeError, AttributeError) as exc:
                raise ValueError(f'{lockfile}: {exc}') from exc
            count += 1
    print(f'[ok] resolved npm minimums validated in {count} lockfile(s)')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError) as exc:
        print(f'[fail] {exc}', file=sys.stderr)
        sys.exit(1)
