#!/usr/bin/env python3
"""Generate/verify the offline State 019 reference-and-workload checkpoint (not deployment)."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

import lab
import prepare_runtime
import workloads

STATE = '019-traderx-security-lab'
SOURCES = [
    'scripts/security-lab/checkpoint.py',
    'scripts/security-lab/prepare_runtime.py',
    'scripts/security-lab/lab.py',
    'scripts/security-lab/workloads.py',
    'specs/012-platform-convergence-c3/security-lab/baseline.lock.json',
    'specs/012-platform-convergence-c3/security-lab/runtime-images.lock.json',
]


def encoded(value):
    return (json.dumps(value, indent=2, sort_keys=True) + '\n').encode()


def sha(data):
    return hashlib.sha256(data).hexdigest()


def baseline_available(commit):
    return subprocess.run(['git', '-C', str(lab.ROOT), 'cat-file', '-e', commit + '^{commit}'],
                          capture_output=True, timeout=15).returncode == 0


def fetch_baseline():
    """Explicit network step; no branch, worktree, image or cluster changes."""
    pin = lab.read_json(lab.PROFILE / 'baseline.lock.json')['generated_commit']
    if not baseline_available(pin):
        subprocess.run(['git', '-C', str(lab.ROOT), 'fetch', '--no-tags',
                        'https://github.com/finos/traderX.git', pin], check=True, timeout=180)
    # Validate the source relationship even when the object was already present.
    baseline = lab.read_json(lab.PROFILE / 'baseline.lock.json')
    if f"Source Commit: `{baseline['canonical_source_commit']}`" not in lab.object_text(pin, 'README.md'):
        raise ValueError('Pinned snapshot/source relationship does not match')
    print('Pinned C3 snapshot available: ' + pin)


def compile_checkpoint():
    baseline = lab.read_json(lab.PROFILE / 'baseline.lock.json')
    if not baseline_available(baseline['generated_commit']):
        raise ValueError('Pinned C3 snapshot missing; run checkpoint.py fetch-baseline first')
    image_lock = lab.read_json(lab.PROFILE / 'runtime-images.lock.json')
    if set(image_lock['images']) != set(baseline['image_digests']):
        raise ValueError('Baseline and image-lock inventories differ')
    reference = prepare_runtime.render_reference(baseline, image_lock, offline=True)
    files = {'reference.json': encoded(reference),
             'business-workloads.json': encoded(workloads.render(reference)),
             'images.lock.json': encoded(image_lock)}
    manifest = {
        'schema_version': 1, 'state': STATE, 'checkpoint': 'reference-and-business-workloads',
        'status': 'offline-artifacts-only',
        'generated_commit': baseline['generated_commit'],
        'canonical_source_commit': baseline['canonical_source_commit'],
        'source_sha256': {p: sha((lab.ROOT / p).read_bytes()) for p in SOURCES},
        'artifact_sha256': {p: sha(data) for p, data in files.items()},
        'limitations': [
            'Not the integrated State 019 runtime; no cluster or enforcement was tested.',
            'Reference includes public demonstration credentials and an unauthenticated broker.',
            'Business-workload restrictions are a separate candidate, not full hardening.',
            'Image pins mix linux/amd64 application images and linux/arm64 infrastructure; other host profiles are unvalidated.',
            'Local hashes establish consistency, not signed provenance or compliance.'
        ]}
    files['checkpoint.json'] = encoded(manifest)
    return files


def generate(output):
    output = Path(output).absolute()
    if output.exists() or output.is_symlink():
        raise ValueError('Output already exists; choose a new directory (no overwrite or reset)')
    files = compile_checkpoint()
    output.parent.mkdir(parents=True, exist_ok=True)
    # Finish rendering before creating output; avoid partial artifacts on failed compilation.
    with tempfile.TemporaryDirectory(prefix='.state019-', dir=output.parent) as temporary:
        staging = Path(temporary) / 'checkpoint'
        staging.mkdir(mode=0o700)
        for name, data in files.items():
            (staging / name).write_bytes(data)
            (staging / name).chmod(0o600)
        staging.rename(output)
    print('Generated offline checkpoint: ' + str(output))


def verify(output):
    output = Path(output)
    expected = compile_checkpoint()
    if not output.is_dir() or output.is_symlink():
        raise ValueError('Expected checkpoint directory')
    if {p.name for p in output.iterdir()} != set(expected):
        raise ValueError('Unexpected or missing checkpoint files')
    for name, data in expected.items():
        path = output / name
        if path.is_symlink() or not path.is_file() or path.read_bytes() != data:
            raise ValueError('Checkpoint differs from pinned inputs: ' + name)
    print('Verified all checkpoint bytes against pinned inputs; runtime acceptance remains pending.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('fetch-baseline', help='Explicitly fetch the immutable C3 commit if absent')
    for name in ('generate', 'verify'):
        sub.add_parser(name).add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.command == 'fetch-baseline':
        fetch_baseline()
    elif args.command == 'generate':
        generate(args.output)
    else:
        verify(args.output)


if __name__ == '__main__':
    main()
