#!/usr/bin/env python3
"""Consume verifier output transported by the deployment workflow over SSH."""
import argparse
import datetime
import json
import os
from pathlib import Path
import re
import subprocess
import uuid


def run(*args, **kwargs):
    return subprocess.run(args, check=True, timeout=kwargs.pop('timeout', 600), **kwargs)


def pin_services(config, images):
    for name, service in config['services'].items():
        image = service.get('image', '')
        reference = image.split('@', 1)[0]
        repository = reference.rsplit(':', 1)[0] if ':' in reference.rsplit('/', 1)[-1] else reference
        if repository in images:
            service['image'] = images[repository]
        elif service.get('build') or image.startswith('ghcr.io/finos/traderx-'):
            raise ValueError(f'no verified published image for service {name}')
        elif not image:
            raise ValueError(f'missing image for service {name}')
        service.pop('build', None)
    return config


def main():
    p = argparse.ArgumentParser(__doc__)
    p.add_argument('manifest')
    p.add_argument('--workdir', default=str(Path.home() / 'traderx'))
    a = p.parse_args()
    record = json.loads(Path(a.manifest).read_text())
    sha = record['snapshot']
    if not re.fullmatch('[0-9a-f]{40}', sha):
        raise ValueError('invalid snapshot')
    work = Path(a.workdir).resolve()
    if not (work / '.git').exists():
        run('git', 'clone', 'https://github.com/' + record['repository'] + '.git', str(work))
    run('git', '-C', str(work), 'fetch', 'origin', sha)
    run('git', '-C', str(work), 'checkout', '--detach', sha)
    actual = subprocess.check_output(['git', '-C', str(work), 'rev-parse', 'HEAD'], text=True).strip()
    if actual != sha:
        raise ValueError('checkout does not match verified snapshot')
    # Reject local tracked modifications before consuming the verified runtime bundle.
    run('git', '-C', str(work), 'diff', '--exit-code', 'HEAD')
    env = dict(os.environ, TRADERX_IMAGE_TAG=sha, TRADERX_FQDN=record['target'])
    env.setdefault('CORS_ALLOWED_ORIGINS', f'https://{record["target"]},http://{record["target"]},http://localhost:8080')
    compose = work / 'runtime/ghcr' / record['state'] / 'docker-compose.ghcr.yml'
    config = json.loads(run('docker', 'compose', '-f', str(compose), 'config', '--format', 'json',
                            env=env, capture_output=True, text=True).stdout)
    config = pin_services(config, record['images'])
    # Resolve infrastructure images once, scan that digest, and use exactly that digest.
    for service in config['services'].values():
        image = service['image']
        if image not in record['images'].values():
            run('docker', 'pull', image)
            digests = json.loads(run('docker', 'image', 'inspect', image, '--format', '{{json .RepoDigests}}',
                                    capture_output=True, text=True).stdout)
            if not digests or not re.search(r'@sha256:[0-9a-f]{64}$', digests[0]):
                raise ValueError(f'cannot resolve immutable infrastructure image: {image}')
            service['image'] = digests[0]
            scanner = 'traderx-security-' + uuid.uuid4().hex
            try:
                run('docker', 'run', '--rm', '--name', scanner, 'aquasec/trivy:0.69.3',
                    'image', '--exit-code', '1', '--severity', 'HIGH,CRITICAL',
                    '--no-progress', service['image'])
            finally:
                try:
                    run('docker', 'rm', '-f', scanner, timeout=5, capture_output=True)
                except (OSError, subprocess.SubprocessError):
                    print(f'[warn] cleanup unconfirmed; inspect {scanner}')
    audit = work / '.traderx-deploy'
    audit.mkdir(mode=0o700, exist_ok=True)
    os.chmod(audit, 0o700)
    resolved = audit / f'{sha}.compose.json'
    resolved.write_text(json.dumps(config, indent=2) + '\n')
    command = ['docker', 'compose', '-f', str(resolved), '--project-name',
               os.environ.get('TRADERX_COMPOSE_PROJECT_NAME', 'traderx-' + record['state'])]
    run(*command, 'pull', env=env)
    run(*command, 'up', '-d', '--no-build', '--wait', '--wait-timeout', '180', env=env)
    record['deployed_at'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    record['services'] = {n: s['image'] for n, s in config['services'].items()}
    (audit / f'{sha}.json').write_text(json.dumps(record, indent=2) + '\n')
    (audit / 'deployed.json').write_text(json.dumps(record, indent=2) + '\n')
    print(f'[ok] deployed and recorded snapshot {sha}')


if __name__ == '__main__':
    main()
