#!/usr/bin/env python3
"""Fail-closed deployment authorization against exact GitHub Actions runs."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import tempfile
import sys
import tarfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
from runtime_image_security import runtime_inventory, validate_lock, validate_published_binding


def gh_json(*args):
    return json.loads(subprocess.check_output(['gh', *args], text=True))


def successful_run(runs, sha, branch, workflow):
    candidates = [r for r in runs if r['head_sha'] == sha and r['head_branch'] == branch
                  and r['event'] == 'push' and r['path'] == '.github/workflows/' + workflow]
    if not candidates:
        raise ValueError(f'missing {workflow} push run for {sha}')
    run = max(candidates, key=lambda r: r['id'])
    if run['status'] != 'completed' or run['conclusion'] != 'success':
        raise ValueError(f'{workflow}: {run["status"]}/{run["conclusion"]}; rerun checks on {sha}')
    return run


def successful_jobs(jobs, required):
    if not jobs or any(j['status'] != 'completed' or j['conclusion'] != 'success' for j in jobs):
        raise ValueError('every required workflow job must complete successfully (no skips)')
    missing = set(required) - {j['name'] for j in jobs}
    if missing:
        raise ValueError(f'missing required jobs: {sorted(missing)}')


def validate_image(record, sha, image, run):
    if (record.get('snapshot') != sha or record.get('image') != image
            or str(record.get('run_id')) != str(run['id'])
            or str(record.get('run_attempt')) != str(run['run_attempt'])
            or not re.fullmatch(r'sha256:[0-9a-f]{64}', record.get('digest', ''))):
        raise ValueError(f'image evidence does not match snapshot/run: {image}')
    return image + '@' + record['digest']



def security_settings():
    root = Path(__file__).resolve().parent.parent
    path = root / 'catalog/dependency-version-targets.json'
    if not path.exists():
        path = root / 'ci/dependency-version-targets.json'
    return json.loads(path.read_text())


def disposition_policy():
    root = Path(__file__).resolve().parent.parent
    path = root / 'catalog/security/state-009-grafana-fixed-findings.json'
    if not path.exists():
        path = root / 'ci/state-009-grafana-fixed-findings.json'
    return json.loads(path.read_text()) if path.exists() else None


def download_snapshot(repository, snapshot, destination):
    """Inspect the actual snapshot runtime, never a caller-supplied image list."""
    # macOS temp paths often traverse /var -> /private/var; compare canonical roots.
    destination = destination.resolve()
    archive = destination / 'snapshot.tar.gz'
    with archive.open('wb') as output:
        subprocess.run(['gh', 'api', f'repos/{repository}/tarball/{snapshot}'], stdout=output, check=True)
    unpacked = destination / 'snapshot'
    unpacked.mkdir()
    with tarfile.open(archive) as source:
        members = source.getmembers()
        if len(members) > 50000 or sum(m.size for m in members) > 512 * 1024 * 1024:
            raise ValueError('snapshot archive is unexpectedly large')
        for member in members:
            path = (unpacked / member.name).resolve()
            if not path.is_relative_to(unpacked) or not (member.isdir() or member.isfile()):
                raise ValueError('unsafe path or link in snapshot archive')
        source.extractall(unpacked, members=members)
    roots = list(unpacked.iterdir())
    if len(roots) != 1 or not roots[0].is_dir():
        raise ValueError('malformed snapshot archive')
    return roots[0]



def main():
    p = argparse.ArgumentParser(__doc__)
    p.add_argument('--snapshot', required=True)
    p.add_argument('--target', required=True)
    p.add_argument('--repository', default='finos/traderX')
    p.add_argument('--output', default='verified-deployment.json')
    a = p.parse_args()
    if not re.fullmatch('[0-9a-f]{40}', a.snapshot):
        p.error('snapshot must be a full lowercase commit SHA')
    root = Path(__file__).resolve().parent.parent
    catalog = root / 'catalog/state-catalog.json'
    if not catalog.exists():
        catalog = root / 'ci/deployment-catalog.json'
    state, = [s for s in json.loads(catalog.read_text())['states']
              if s.get('deploy', {}).get('domain') == a.target and s['deploy'].get('enabled')]
    branch = state['publish']['branch']
    repo = f'repos/{a.repository}'
    # Require an actual commit on the intended generated branch, never another state's SHA.
    tip = gh_json('api', f'{repo}/commits/{branch}')
    if tip['sha'] != a.snapshot:
        raise ValueError('snapshot is not the current generated branch tip; regenerate/reverify before deploying')
    import base64
    content = gh_json('api', f'{repo}/contents/ci/state-metadata.json?ref={a.snapshot}')
    metadata = json.loads(base64.b64decode(content['content']))
    if metadata.get('stateId') != state['id']:
        raise ValueError('snapshot metadata does not match demo state')
    modules = metadata['modules']
    images = [m['imageName'] for m in modules['docker']]
    if not images:
        raise ValueError('no application images in snapshot')
    required = {
        'build-and-test.yml': ['Build and test snapshot'],
        'security.yml': [f'{m}-{kind}-scan' for kind in ('node', 'dotnet', 'gradle')
                         for m in modules[kind]] + [f'{name}-docker-scan' for name in images],
        'build-and-publish.yml': [f'Build and push {name}' for name in images] + ['Runtime Image Security'],
    }
    evidence = {}
    for workflow, names in required.items():
        pages = gh_json('api', '--paginate', '--slurp',
                        f'{repo}/actions/workflows/{workflow}/runs?head_sha={a.snapshot}&per_page=100')
        run = successful_run([r for page in pages for r in page['workflow_runs']],
                             a.snapshot, branch, workflow)
        pages = gh_json('api', '--paginate', '--slurp',
                        f'{repo}/actions/runs/{run["id"]}/attempts/{run["run_attempt"]}/jobs?per_page=100')
        successful_jobs([j for page in pages for j in page['jobs']], names)
        evidence[workflow] = run
    run = evidence['build-and-publish.yml']
    namespace = 'traderx-' + state['convergenceLevel'].lower()
    verified = {}
    with tempfile.TemporaryDirectory() as tmp:
        for name in images:
            artifact = f'image-digest-{name}-{run["run_attempt"]}'
            dest = Path(tmp) / name
            subprocess.run(['gh', 'run', 'download', str(run['id']), '--repo', a.repository,
                            '--name', artifact, '--dir', str(dest)], check=True)
            image = f'ghcr.io/finos/{namespace}/{name}'
            verified[image] = validate_image(json.loads((dest / 'image.json').read_text()),
                                             a.snapshot, image, run)
        runtime_dir = Path(tmp) / 'runtime-evidence'
        subprocess.run(['gh', 'run', 'download', str(run['id']), '--repo', a.repository,
                        '--name', f'runtime-lock-{run["run_attempt"]}', '--dir', str(runtime_dir)], check=True)
        runtime_lock = json.loads((runtime_dir / 'runtime-lock.json').read_text())
        snapshot_root = download_snapshot(a.repository, a.snapshot, Path(tmp))
        entries = runtime_inventory(snapshot_root, metadata, a.snapshot)
        locks = validate_lock(runtime_lock, metadata, entries, a.repository, a.snapshot,
                              run['id'], run['run_attempt'], security_settings(), disposition=disposition_policy())
        validate_published_binding(locks, verified)
    record = {'snapshot': a.snapshot, 'state': state['id'], 'target': a.target,
              'repository': a.repository, 'branch': branch, 'images': verified,
              'runtime_lock': runtime_lock, 'runtime_metadata': metadata,
              'runtime_images': locks,
              'checks': {w: {'id': r['id'], 'attempt': r['run_attempt'], 'url': r['html_url']}
                         for w, r in evidence.items()}}
    Path(a.output).write_text(json.dumps(record, indent=2) + '\n')
    print(f'[ok] verified {a.snapshot}; deployment evidence: {a.output}')


if __name__ == '__main__':
    main()
