#!/usr/bin/env python3
"""Consume verifier output transported by the deployment workflow over SSH."""
import argparse
import datetime
import json
import os
from pathlib import Path
import re
import shutil
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


def already_fixed(finding, image, policy, now=None):
    if not policy or image != policy.get('image'):
        return False
    if policy.get('approved') is not True:
        raise ValueError('fixed-source disposition is not approved')
    now = now or datetime.datetime.now(datetime.timezone.utc)
    expiry = datetime.datetime.fromisoformat(policy['expires'].replace('Z', '+00:00'))
    if now >= expiry:
        raise ValueError('fixed-source disposition expired')
    return (finding.get('PkgName') == policy['package']
            and finding.get('InstalledVersion') == policy['installed_version']
            and finding.get('VulnerabilityID') in policy['fixed_findings'])


def scan_infrastructure(config, images, reports, policy=None):
    """Inventory every infrastructure blocker; diagnostic output is not authorization."""
    reports.mkdir(mode=0o700, parents=True, exist_ok=False)
    summary = []
    for name, service in config['services'].items():
        image = service['image']
        # Rebuilt infrastructure now has published-image evidence too, but
        # must retain its independent host scan before runtime replacement.
        infrastructure = {'database', 'blackbox-exporter', 'prometheus', 'loki', 'tempo',
                          'grafana', 'promtail', 'otel-collector', 'nats-broker'}
        if image in images.values() and name not in infrastructure:
            continue
        if not re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9_.-]*', name):
            raise ValueError('invalid service name')
        entry = dict(service=name, source=image, status='error', high=0, critical=0, fixed_findings=[])
        scanner = 'traderx-security-' + uuid.uuid4().hex
        try:
            run('docker', 'pull', image, capture_output=True, text=True)
            digests = json.loads(run('docker', 'image', 'inspect', image, '--format', '{{json .RepoDigests}}',
                                    capture_output=True, text=True).stdout)
            if not isinstance(digests, list) or not digests or not isinstance(digests[0], str) or not re.search(r'@sha256:[0-9a-f]{64}$', digests[0]):
                raise ValueError('cannot resolve immutable infrastructure image')
            entry['digest'] = service['image'] = digests[0]
            result = subprocess.run(
                ['docker', 'run', '--rm', '--name', scanner, 'aquasec/trivy:0.76.2@sha256:8f6bb947dbc528902e11f2f5be52f7b519f6a39d5d148f41166f2040499768fb',
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
                        if already_fixed(finding, service['image'], policy):
                            entry['fixed_findings'].append({k: finding.get(k) for k in
                                ('VulnerabilityID', 'PkgName', 'InstalledVersion', 'Severity')})
                        else:
                            entry[finding['Severity'].lower()] += 1
                for secret in target.get('Secrets', []):
                    if not isinstance(secret, dict) or 'Severity' not in secret:
                        raise ValueError('malformed secret finding')
                    if secret['Severity'] in ('HIGH', 'CRITICAL'):
                        entry[secret['Severity'].lower()] += 1
            findings = entry['high'] + entry['critical']
            if result.returncode not in (0, 1) or (result.returncode == 1 and not findings and not entry['fixed_findings']):
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
        print(f"[scan] {name}: {entry['status']} HIGH={entry['high']} CRITICAL={entry['critical']} already-fixed={len(entry['fixed_findings'])}")
    # Also retain a complete empty inventory for application-only runtimes.
    (reports / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    blocked = [e['service'] for e in summary if e['status'] != 'success']
    if blocked:
        raise ValueError('infrastructure preflight blocked: ' + ', '.join(blocked))


def backup_state009_database(record, project, audit):
    """Never silently create an empty replacement for the recovered demo volume."""
    if record['state'] != '009-order-management-matcher':
        return
    volume = project + '_postgres_state_009_data'
    details = json.loads(run('docker', 'volume', 'inspect', volume, capture_output=True, text=True).stdout)
    if len(details) != 1 or details[0].get('Name') != volume:
        raise ValueError('expected existing PostgreSQL volume was not found')
    mount = details[0]['Mountpoint']
    version = run('sudo', '-n', 'cat', mount + '/PG_VERSION', capture_output=True, text=True).stdout.strip()
    if version != '16':
        raise ValueError(f'PostgreSQL volume major version is {version}, expected 16')
    writers = run('docker', 'ps', '-q', '--filter', 'volume=' + volume,
                  capture_output=True, text=True).stdout.strip()
    if writers:
        raise ValueError('database volume is in use; arrange a consistent online backup before replacement')
    size = int(run('sudo', '-n', 'du', '-sb', mount, capture_output=True, text=True).stdout.split()[0])
    if shutil.disk_usage(audit).free < size + 512 * 1024 * 1024:
        raise ValueError('insufficient space for database backup')
    backups = audit / 'backups'
    backups.mkdir(mode=0o700, exist_ok=True)
    dest = backups / (record['snapshot'] + '-' + uuid.uuid4().hex + '.tar.gz')
    # The database is offline; preserve ownership in a physical backup without
    # changing the volume or exposing its contents in Actions logs/artifacts.
    run('sudo', '-n', 'tar', '--numeric-owner', '-czf', str(dest), '-C', mount, '.', timeout=600)
    run('sudo', '-n', 'chown', f'{os.getuid()}:{os.getgid()}', str(dest))
    os.chmod(dest, 0o600)
    listing = run('tar', '-tzf', str(dest), capture_output=True, text=True).stdout.splitlines()
    if './PG_VERSION' not in listing:
        raise ValueError('database backup verification failed')
    import hashlib
    with dest.open('rb') as source:
        digest = hashlib.file_digest(source, 'sha256').hexdigest() if hasattr(hashlib, 'file_digest') else None
        if digest is None:
            hasher = hashlib.sha256()
            for block in iter(lambda: source.read(1024 * 1024), b''):
                hasher.update(block)
            digest = hasher.hexdigest()
    record['database_backup'] = {'volume': volume, 'path': str(dest), 'sha256': digest, 'major': version}
    (backups / (dest.name + '.json')).write_text(json.dumps(record['database_backup'], indent=2) + '\n')
    print(f'[ok] verified offline PostgreSQL 16 backup: {dest.name}')


def reclaim_recovery_image_cache(record, audit):
    """Scoped empty-host recovery: remove only old unused image cache, never volumes."""
    if record['state'] != '009-order-management-matcher' or record['target'] != 'demo-advanced.traderx.finos.org':
        raise ValueError('image-cache recovery is restricted to state 009 on demo-advanced')
    if run('docker', 'ps', '-aq', capture_output=True, text=True).stdout.strip():
        raise ValueError('image-cache recovery requires an empty container inventory')
    before = run('df', '-h', '/', capture_output=True, text=True).stdout
    result = run('docker', 'image', 'prune', '-a', '-f', '--filter', 'until=24h', capture_output=True, text=True)
    after = run('df', '-h', '/', capture_output=True, text=True).stdout
    (audit / 'recovery-image-cache.json').write_text(json.dumps(
        {'before': before, 'prune': result.stdout, 'after': after}, indent=2) + '\n')
    print('[ok] reclaimed old unused image cache; no containers or volumes removed')
    print(after)


def main():
    p = argparse.ArgumentParser(__doc__)
    p.add_argument('manifest')
    p.add_argument('--workdir', default=str(Path.home() / 'traderx'))
    p.add_argument('--preflight-only', action='store_true',
                   help='verify and scan infrastructure without starting/replacing containers')
    p.add_argument('--reclaim-unused-images', action='store_true', help='empty state-009 demo host only: reclaim old unused image cache')
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
    if a.reclaim_unused_images:
        reclaim_recovery_image_cache(record, audit)
    policy_file = Path(__file__).with_name('state-009-grafana-fixed-findings.json')
    policy = json.loads(policy_file.read_text()) if policy_file.exists() else None
    scan_infrastructure(config, record['images'],
                        a.report_dir or audit / f'{sha}.scans-{uuid.uuid4().hex}', policy=policy)
    if a.preflight_only:
        print(f'[ok] preflight passed for {sha}; no containers replaced')
        return
    resolved = audit / f'{sha}.compose.json'
    resolved.write_text(json.dumps(config, indent=2) + '\n')
    project = os.environ.get('TRADERX_COMPOSE_PROJECT_NAME', 'traderx-' + record['state'])
    backup_state009_database(record, project, audit)
    command = ['docker', 'compose', '-f', str(resolved), '--project-name', project]
    run(*command, 'pull', env=env)
    run(*command, 'up', '-d', '--no-build', '--wait', '--wait-timeout', '180', env=env)
    record['deployed_at'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    record['services'] = {n: s['image'] for n, s in config['services'].items()}
    (audit / f'{sha}.json').write_text(json.dumps(record, indent=2) + '\n')
    (audit / 'deployed.json').write_text(json.dumps(record, indent=2) + '\n')
    print(f'[ok] deployed and recorded snapshot {sha}')


if __name__ == '__main__':
    main()
