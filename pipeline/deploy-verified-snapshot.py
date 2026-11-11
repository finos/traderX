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


def scan_infrastructure(config, images, reports):
    """Inventory every infrastructure blocker; diagnostic output is not authorization."""
    reports.mkdir(mode=0o700, parents=True, exist_ok=False)
    summary = []
    for name, service in config['services'].items():
        image = service['image']
        if image in images.values():
            continue
        if not re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9_.-]*', name):
            raise ValueError('invalid service name')
        entry = dict(service=name, source=image, status='error', high=0, critical=0)
        scanner = 'traderx-security-' + uuid.uuid4().hex
        try:
            run('docker', 'pull', image, capture_output=True, text=True)
            digests = json.loads(run('docker', 'image', 'inspect', image, '--format', '{{json .RepoDigests}}',
                                    capture_output=True, text=True).stdout)
            if not isinstance(digests, list) or not digests or not isinstance(digests[0], str) or not re.search(r'@sha256:[0-9a-f]{64}$', digests[0]):
                raise ValueError('cannot resolve immutable infrastructure image')
            entry['digest'] = service['image'] = digests[0]
            result = subprocess.run(
                ['docker', 'run', '--rm', '--name', scanner, 'aquasec/trivy:0.69.3',
                 'image', '--exit-code', '1', '--severity', 'HIGH,CRITICAL',
                 '--format', 'json', '--no-progress', service['image']],
                capture_output=True, text=True, timeout=600)
            (reports / f'{name}.trivy.json').write_text(result.stdout)
            (reports / f'{name}.stderr.txt').write_text(result.stderr)
            report = json.loads(result.stdout)
            if not isinstance(report, dict) or not isinstance(report.get('Results'), list):
                raise ValueError('missing or malformed scanner results')
            for target in report['Results']:
                if not isinstance(target, dict):
                    raise ValueError('malformed scanner target')
                vulnerabilities = target.get('Vulnerabilities', [])
                if not isinstance(vulnerabilities, list):
                    raise ValueError('malformed vulnerabilities')
                for finding in vulnerabilities:
                    if not isinstance(finding, dict) or finding.get('Severity') not in ('UNKNOWN', 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'):
                        raise ValueError('malformed vulnerability')
                    if finding['Severity'] in ('HIGH', 'CRITICAL'):
                        entry[finding['Severity'].lower()] += 1
            findings = entry['high'] + entry['critical']
            if result.returncode not in (0, 1) or (result.returncode == 1 and not findings):
                raise ValueError(f'scanner failed with exit code {result.returncode}')
            entry['status'] = 'findings' if findings else 'success'
        except (OSError, subprocess.SubprocessError, ValueError, TypeError) as exc:
            entry['error'] = str(exc)
            if isinstance(exc, subprocess.CalledProcessError):
                (reports / f'{name}.stderr.txt').write_text(exc.stderr or '')
        finally:
            try:
                run('docker', 'rm', '-f', scanner, timeout=5, capture_output=True)
            except (OSError, subprocess.SubprocessError):
                entry['cleanup_warning'] = f'inspect {scanner}'
            summary.append(entry)
            (reports / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        print(f"[scan] {name}: {entry['status']} HIGH={entry['high']} CRITICAL={entry['critical']}")
    # Also retain a complete empty inventory for application-only runtimes.
    (reports / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    blocked = [e['service'] for e in summary if e['status'] != 'success']
    if blocked:
        raise ValueError('infrastructure preflight blocked: ' + ', '.join(blocked))


def main():
    p = argparse.ArgumentParser(__doc__)
    p.add_argument('manifest')
    p.add_argument('--workdir', default=str(Path.home() / 'traderx'))
    p.add_argument('--preflight-only', action='store_true',
                   help='verify and scan infrastructure without starting/replacing containers')
    p.add_argument('--report-dir', type=Path, help='new private directory for infrastructure scan reports')
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
    audit = work / '.traderx-deploy'
    audit.mkdir(mode=0o700, exist_ok=True)
    os.chmod(audit, 0o700)
    scan_infrastructure(config, record['images'],
                        a.report_dir or audit / f'{sha}.scans-{uuid.uuid4().hex}')
    if a.preflight_only:
        print(f'[ok] preflight passed for {sha}; no containers replaced')
        return
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
