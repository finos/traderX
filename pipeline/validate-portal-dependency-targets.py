#!/usr/bin/env python3
"""Keep the portal manifest and resolved root packages aligned with central policy."""
import json
from pathlib import Path


def validate(root):
    policy = json.loads((root / 'catalog/dependency-version-targets.json').read_text())['npm']['portal']
    manifest = json.loads((root / 'website/package.json').read_text())
    lock = json.loads((root / 'website/package-lock.json').read_text())
    errors = []
    for name, version in policy['dependencies'].items():
        if manifest.get('dependencies', {}).get(name) != version:
            errors.append(f'portal manifest differs from selected {name} {version}')
        if lock['packages'].get('node_modules/' + name, {}).get('version') != version:
            errors.append(f'portal lock differs from selected {name} {version}')
    if manifest.get('overrides', {}) != policy['overrides']:
        errors.append('portal overrides differ from central policy')
    if set(policy.get('overrideExceptions', {})) != set(policy['overrides']):
        errors.append('every retained portal override requires an explicit exception record')
    for name, exception in policy.get('overrideExceptions', {}).items():
        if not all(exception.get(k) for k in ['owner', 'trackingIssue', 'reason', 'removeWhen']):
            errors.append(f'incomplete portal override retirement condition: {name}')
    for name in policy.get('removedDependencies', []):
        if name in manifest.get('dependencies', {}) or name in manifest.get('devDependencies', {}):
            errors.append(f'retired unused portal dependency reintroduced: {name}')
    return errors


if __name__ == '__main__':
    errors = validate(Path(__file__).resolve().parents[1])
    if errors:
        raise SystemExit('\n'.join(errors))
    print('[ok] portal dependencies and explicit override exceptions match central policy')
