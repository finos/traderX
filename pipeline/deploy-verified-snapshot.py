#!/usr/bin/env python3
"""Consume verifier output transported by the deployment workflow over SSH."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import uuid
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from runtime_image_security import compose_inventory, validate_lock, policy_settings, timestamp, fresh, database_age_limit


class InfrastructureScanBlocked(ValueError):
    pass


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
    expiry = timestamp(policy['expires'])
    if now >= expiry:
        raise ValueError('fixed-source disposition expired')
    return (finding.get('PkgName') == policy['package']
            and finding.get('InstalledVersion') == policy['installed_version']
            and finding.get('VulnerabilityID') in policy['fixed_findings'])


def scan_infrastructure(config, images, reports, policy=None, authorized=None, scanner_image=None, database_ready=False):
    """Inventory every infrastructure blocker; diagnostic output is not authorization."""
    reports.mkdir(mode=0o700, parents=True, exist_ok=False)
    summary = []
    cache = reports.parent / '.trivy-cache'
    cache.mkdir(mode=0o700, exist_ok=True)
    for name, service in config['services'].items():
        image = service['image']
        # Rebuilt infrastructure now has published-image evidence too, but
        # must retain its independent host scan before runtime replacement.
        infrastructure = {'database', 'blackbox-exporter', 'prometheus', 'loki', 'tempo',
                          'grafana', 'promtail', 'otel-collector', 'nats-broker'}
        if authorized is None and image in images.values() and name not in infrastructure:
            continue
        if not re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9_.-]*', name):
            raise ValueError('invalid service name')
        entry = dict(service=name, source=image, status='error', high=0, critical=0, fixed_findings=[])
        scanner = 'traderx-security-' + uuid.uuid4().hex
        if authorized is not None:
            lock = authorized['compose/' + name]
            if image != lock['image']:
                raise ValueError('host image differs from verified platform digest')
        try:
            if authorized is not None:
                entry['digest'] = image
                disposition_image = lock['index_image']
                run('docker', 'pull', '--platform', lock['platform'], image, capture_output=True, text=True)
            else:
                run('docker', 'pull', image, capture_output=True, text=True)
                digests = json.loads(run('docker', 'image', 'inspect', image, '--format', '{{json .RepoDigests}}',
                                        capture_output=True, text=True).stdout)
                if not isinstance(digests, list) or not digests or not isinstance(digests[0], str) or not re.search(r'@sha256:[0-9a-f]{64}$', digests[0]):
                    raise ValueError('cannot resolve immutable infrastructure image')
                entry['digest'] = service['image'] = digests[0]
                disposition_image = service['image']
            scanner_args = ['docker', 'run', '--rm', '--name', scanner, '--user', f'{os.getuid()}:{os.getgid()}',
                            '-v', str(cache.resolve()) + ':/cache', scanner_image or policy_settings(security_settings())['runtimeImageScanner']['image'],
                            'image', '--cache-dir', '/cache']
            if database_ready:
                scanner_args += ['--skip-db-update', '--skip-java-db-update']
            result = subprocess.run(
                scanner_args + ['--scanners', 'vuln,secret', '--exit-code', '1', '--severity', 'HIGH,CRITICAL',
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
                        if already_fixed(finding, disposition_image, policy):
                            entry['fixed_findings'].append({k: finding.get(k) for k in
                                ('VulnerabilityID', 'PkgName', 'InstalledVersion', 'Severity')})
                        else:
                            entry[finding['Severity'].lower()] += 1
                for secret in target.get('Secrets', []):
                    if not isinstance(secret, dict) or secret.get('Severity') not in ('UNKNOWN', 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'):
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
    public = [{key: entry.get(key) for key in ('service', 'status', 'high', 'critical')}
              for entry in summary]
    (reports / 'public-summary.json').write_text(json.dumps(public, indent=2) + '\n')
    blocked = [e['service'] for e in summary if e['status'] != 'success']
    if blocked:
        raise InfrastructureScanBlocked('infrastructure preflight blocked: ' + ', '.join(blocked))
    return summary


def refresh_scanner_databases(cache, settings, evidence=None):
    policy = policy_settings(settings)
    cache.mkdir(mode=0o700, parents=True, exist_ok=True)
    scanner = policy['runtimeImageScanner']['image']
    if evidence is None:
        evidence = {}
    for name, flag, relative in [('vulnerability', '--download-db-only', 'db/metadata.json'),
                                 ('java', '--download-java-db-only', 'java-db/metadata.json')]:
        container = 'traderx-security-' + uuid.uuid4().hex
        try:
            run('docker', 'run', '--rm', '--name', container, '--user', f'{os.getuid()}:{os.getgid()}',
                '-v', str(cache.resolve()) + ':/cache', scanner, 'image', '--cache-dir', '/cache',
                '--no-progress', flag, capture_output=True, text=True)
            raw = (cache / relative).read_bytes()
            metadata = json.loads(raw)
            fresh(metadata.get('UpdatedAt'), database_age_limit(policy, name))
            evidence[name] = {'updated_at': metadata['UpdatedAt'],
                              'sha256': hashlib.sha256(raw).hexdigest()}
        finally:
            try:
                run('docker', 'rm', '-f', container, timeout=5, capture_output=True)
            except (OSError, subprocess.SubprocessError):
                print(f'[warn] inspect scanner container {container}')
    return evidence


def state009_database_volume(config):
    """Use Compose's resolved volume name, including explicit name overrides."""
    mounts = config.get('services', {}).get('database', {}).get('volumes', [])
    data = [m for m in mounts if isinstance(m, dict)
            and m.get('target') == '/var/lib/postgresql/data']
    if len(data) != 1 or data[0].get('type') != 'volume':
        raise ValueError('expected one named PostgreSQL data volume')
    volume = config.get('volumes', {}).get(data[0].get('source'), {}).get('name')
    if not isinstance(volume, str) or not re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9_.-]*', volume):
        raise ValueError('PostgreSQL volume name must be resolved by Compose')
    return volume


def backup_state009_database(record, project, audit, config):
    """Preserve state-009 data; quiesce only its verified project for a physical backup."""
    if record['state'] != '009-order-management-matcher':
        return
    volume = state009_database_volume(config)
    # Inspect this project's database independently of the selected volume: an
    # obsolete offline volume must never conceal a live database on another mount.
    database_ids = run('docker', 'ps', '-aq', '--filter',
                       'label=com.docker.compose.project=' + project, '--filter',
                       'label=com.docker.compose.service=database',
                       capture_output=True, text=True).stdout.split()
    if database_ids:
        if len(database_ids) != 1 or not re.fullmatch(r'[0-9a-f]{12,64}', database_ids[0]):
            raise ValueError('expected one existing project database container')
        existing = json.loads(run('docker', 'inspect', *database_ids,
                                  capture_output=True, text=True).stdout)
        if len(existing) != 1:
            raise ValueError('invalid existing database inventory')
        labels = existing[0].get('Config', {}).get('Labels') or {}
        data_mounts = [m for m in existing[0].get('Mounts', [])
                       if m.get('Destination') == '/var/lib/postgresql/data']
        if (labels.get('com.docker.compose.project') != project
                or labels.get('com.docker.compose.service') != 'database'
                or len(data_mounts) != 1 or data_mounts[0].get('Type') != 'volume'
                or data_mounts[0].get('Name') != volume):
            raise ValueError('existing database mount differs from resolved Compose volume')
    details = json.loads(run('docker', 'volume', 'inspect', volume, capture_output=True, text=True).stdout)
    if len(details) != 1 or details[0].get('Name') != volume:
        raise ValueError('expected existing PostgreSQL volume was not found')
    mount = details[0]['Mountpoint']
    version = run('sudo', '-n', 'cat', mount + '/PG_VERSION', capture_output=True, text=True).stdout.strip()
    if version != '16':
        raise ValueError(f'PostgreSQL volume major version is {version}, expected 16')
    writers = run('docker', 'ps', '-q', '--filter', 'volume=' + volume,
                  capture_output=True, text=True).stdout.split()
    stopped = []
    if writers:
        if any(not re.fullmatch(r'[0-9a-f]{12,64}', cid) for cid in writers):
            raise ValueError('invalid database writer identity')
        owners = json.loads(run('docker', 'inspect', *writers, capture_output=True, text=True).stdout)
        if len(owners) != 1:
            raise ValueError('expected one database writer')
        labels = owners[0].get('Config', {}).get('Labels') or {}
        if (labels.get('com.docker.compose.project') != project
                or labels.get('com.docker.compose.service') != 'database'):
            raise ValueError('database volume has an unexpected writer; refusing to stop it')
        mounts = owners[0].get('Mounts', [])
        destinations = [m['Destination'] for m in mounts if m.get('Name') == volume]
        if len(destinations) != 1:
            raise ValueError('cannot identify database volume destination')
        if any(m['Destination'].startswith(destinations[0].rstrip('/') + '/') for m in mounts):
            raise ValueError('physical backup refuses nested database container mounts')
        stopped = run('docker', 'ps', '-q', '--filter', 'label=com.docker.compose.project=' + project,
                      capture_output=True, text=True).stdout.split()
        if not stopped or any(not re.fullmatch(r'[0-9a-f]{12,64}', cid) for cid in stopped):
            raise ValueError('invalid project container inventory')
        if not set(writers).issubset(set(stopped)):
            raise ValueError('database writer is absent from project inventory')
    # Container mounts and host bind mounts can hide data outside this volume.
    mountinfo = run('sudo', '-n', 'cat', '/proc/self/mountinfo', capture_output=True, text=True).stdout
    for line in mountinfo.splitlines():
        fields = line.split()
        if len(fields) < 6:
            raise ValueError('invalid host mount inventory')
        location = re.sub(r'\\([0-7]{3})', lambda m: chr(int(m[1], 8)), fields[4])
        if location.startswith(mount.rstrip('/') + '/'):
            raise ValueError('physical backup refuses nested database host mounts')
    if run('sudo', '-n', 'find', mount, '-type', 'l', '-print', capture_output=True, text=True).stdout.strip():
        raise ValueError('physical backup requires standard PostgreSQL layout without data symlinks')
    size = int(run('sudo', '-n', 'du', '-sb', mount, capture_output=True, text=True).stdout.split()[0])
    if shutil.disk_usage(audit).free < size + 512 * 1024 * 1024:
        raise ValueError('insufficient space for database backup')
    backups = audit / 'backups'
    backups.mkdir(mode=0o700, exist_ok=True)
    dest = backups / (record['snapshot'] + '-' + uuid.uuid4().hex + '.tar.gz')
    try:
        if stopped:
            run('docker', 'stop', '--time', '60', *stopped, capture_output=True, text=True, timeout=120)
        # Check immediately before copying, including the initially offline path.
        if run('docker', 'ps', '-q', '--filter', 'volume=' + volume,
               capture_output=True, text=True).stdout.strip():
            raise ValueError('database volume still has a running writer; backup refused')
        run('sudo', '-n', 'tar', '--numeric-owner', '-czf', str(dest), '-C', mount, '.', timeout=600)
        run('sudo', '-n', 'chown', f'{os.getuid()}:{os.getgid()}', str(dest))
        os.chmod(dest, 0o600)
        listing = run('tar', '-tzf', str(dest), capture_output=True, text=True).stdout.splitlines()
        if './PG_VERSION' not in listing:
            raise ValueError('database backup verification failed')
        hasher = hashlib.sha256()
        with dest.open('rb') as source:
            for block in iter(lambda: source.read(1024 * 1024), b''):
                hasher.update(block)
        record['database_backup'] = {'volume': volume, 'path': str(dest),
                                     'sha256': hasher.hexdigest(), 'major': version,
                                     'method': 'quiesced-physical' if stopped else 'offline-physical'}
        (backups / (dest.name + '.json')).write_text(json.dumps(record['database_backup'], indent=2) + '\n')
    except BaseException:
        if stopped:
            try:
                active = run('docker', 'ps', '-q', '--filter', 'volume=' + volume,
                             capture_output=True, text=True).stdout.split()
                # A writer that appeared during backup invalidates the copy;
                # never start the old database alongside that writer.
                safe = [cid for cid in stopped if not active or cid not in writers]
                if safe:
                    run('docker', 'start', *safe, capture_output=True, text=True, timeout=120)
            except (OSError, subprocess.SubprocessError) as exc:
                print(f'[fail] restoring quiesced project failed: {exc}')
        raise
    print(f'[ok] verified PostgreSQL 16 backup ({record["database_backup"]["method"]}): {dest.name}')
    return stopped


def resume_unchanged_containers(project, stopped, volume):
    """On failed startup, resume retained originals only; never replace newer data writers."""
    if not stopped:
        return
    ids = run('docker', 'ps', '-aq', '--filter', 'label=com.docker.compose.project=' + project,
              capture_output=True, text=True).stdout.split()
    if not ids:
        return
    if any(not re.fullmatch(r'[0-9a-f]{12,64}', cid) for cid in ids):
        raise ValueError('invalid project container identity during startup recovery')
    containers = json.loads(run('docker', 'inspect', *ids, capture_output=True, text=True).stdout)
    by_service = {}
    for item in containers:
        labels = item.get('Config', {}).get('Labels') or {}
        if labels.get('com.docker.compose.project') != project:
            raise ValueError('unexpected project during startup recovery')
        by_service.setdefault(labels.get('com.docker.compose.service'), []).append(item)
    resume = []
    for service, items in by_service.items():
        # A replacement may already have committed writes. Never start an old
        # container alongside it or roll back its database filesystem.
        if len(items) != 1:
            continue
        item = items[0]
        if any(item['Id'].startswith(cid) for cid in stopped) and not item['State']['Running']:
            if service == 'database':
                active = run('docker', 'ps', '-q', '--filter',
                             'volume=' + volume,
                             capture_output=True, text=True).stdout.strip()
                if active:
                    continue
            resume.append(item['Id'])
    if resume:
        run('docker', 'start', *resume, capture_output=True, text=True, timeout=120)
        print(f'[warn] resumed {len(resume)} unchanged prior containers after failed startup')


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



def security_settings():
    adjacent = Path(__file__).with_name('dependency-version-targets.json')
    path = adjacent if adjacent.exists() else Path(__file__).resolve().parents[1] / 'catalog/dependency-version-targets.json'
    return json.loads(path.read_text())


def authorize_runtime(config, record, settings, policy):
    platform = run('docker', 'version', '--format', '{{.Server.Os}}/{{.Server.Arch}}',
                   capture_output=True, text=True).stdout.strip()
    if platform != 'linux/amd64':
        raise ValueError('host platform is not covered by runtime security evidence')
    metadata = record['runtime_metadata']
    if metadata['stateId'] != record['state'] or metadata['runtime']['kind'] != 'compose':
        raise ValueError('runtime metadata does not match deployment state')
    evidence = record['checks']['build-and-publish.yml']
    locks = validate_lock(record['runtime_lock'], metadata, compose_inventory(config),
                          record['repository'], record['snapshot'], evidence['id'], evidence['attempt'],
                          settings, disposition=policy, allow_stale=True)
    if record.get('runtime_images') != locks:
        raise ValueError('deployment runtime image map differs from verified evidence')
    for name, service in config['services'].items():
        service['image'] = locks['compose/' + name]['image']
        service.pop('build', None)
    return locks


def review_runtime_scans(config, record, authorized, settings, policy, reports):
    emergency = record.get('break_glass', {}).get('enabled') is True
    if emergency:
        exception = record['break_glass']
        if (not isinstance(exception.get('reason'), str)
                or not 10 <= len(exception['reason'].strip()) <= 500
                or '\n' in exception['reason'] or '\r' in exception['reason']
                or not isinstance(exception.get('actor'), str) or not exception['actor']):
            raise ValueError('break-glass deployment requires an actor and a reason')
    issues = []
    databases = {}
    database_ready = False
    completed = False
    try:
        try:
            refreshed = refresh_scanner_databases(reports.parent / '.trivy-cache', settings,
                                                  evidence=databases)
            databases = refreshed
            database_ready = True
        except (OSError, subprocess.SubprocessError, ValueError, KeyError, TypeError) as exc:
            issues.append('scanner database unavailable or stale')
            if not emergency:
                raise
            print(f'[warn] break-glass: scanner database refresh failed: {type(exc).__name__}')
        try:
            scan_infrastructure(config, record['images'], reports, policy=policy,
                                authorized=authorized, scanner_image=policy_settings(settings)['runtimeImageScanner']['image'],
                                database_ready=database_ready)
        except InfrastructureScanBlocked:
            issues.append('runtime image scans reported findings or errors')
            if not emergency:
                raise
            print('[warn] break-glass: continuing despite runtime image scan findings or errors')
        completed = True
    finally:
        # Retain only allowlisted evidence even when normal-mode validation raises.
        reports.mkdir(mode=0o700, parents=True, exist_ok=True)
        summary = json.loads((reports / 'summary.json').read_text()) if (reports / 'summary.json').exists() else []
        results = [{key: entry.get(key) for key in ('service', 'status', 'high', 'critical')}
                   for entry in summary]
        review = {'status': 'completed' if completed else 'blocked',
                  'issues': issues if completed or issues else ['runtime scan did not complete'],
                  'break_glass': record.get('break_glass', {'enabled': False}),
                  'databases': databases, 'results': results}
        (reports / 'public-summary.json').write_text(json.dumps(results, indent=2) + '\n')
        (reports / 'scan-review.json').write_text(json.dumps(review, indent=2) + '\n')
    return review



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
    audit = work / '.traderx-deploy'
    audit.mkdir(mode=0o700, exist_ok=True)
    os.chmod(audit, 0o700)
    if a.reclaim_unused_images:
        reclaim_recovery_image_cache(record, audit)
    policy_file = Path(__file__).with_name('state-009-grafana-fixed-findings.json')
    policy = json.loads(policy_file.read_text()) if policy_file.exists() else None
    settings = security_settings()
    authorized = authorize_runtime(config, record, settings, policy)
    reports = a.report_dir or audit / f'{sha}.scans-{uuid.uuid4().hex}'
    record['scan_review'] = review_runtime_scans(config, record, authorized, settings, policy, reports)
    if a.preflight_only:
        if record['scan_review']['issues']:
            print(f'[warn] preflight completed with break-glass exceptions for {sha}; no containers replaced')
        else:
            print(f'[ok] preflight passed for {sha}; no containers replaced')
        return
    resolved = audit / f'{sha}.compose.json'
    resolved.write_text(json.dumps(config, indent=2) + '\n')
    project = os.environ.get('TRADERX_COMPOSE_PROJECT_NAME', 'traderx-' + record['state'])
    command = ['docker', 'compose', '-f', str(resolved), '--project-name', project]
    run(*command, 'pull', env=env)
    # Pull every image before entering the brief database maintenance window.
    stopped = backup_state009_database(record, project, audit, config)
    try:
        run(*command, 'up', '-d', '--no-build', '--wait', '--wait-timeout', '180', env=env)
    except BaseException:
        try:
            if stopped:
                resume_unchanged_containers(project, stopped, record['database_backup']['volume'])
        except (ValueError, OSError, subprocess.SubprocessError) as exc:
            print(f'[fail] resuming unchanged containers failed: {exc}')
        raise
    record['deployed_at'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    record['services'] = {n: s['image'] for n, s in config['services'].items()}
    (audit / f'{sha}.json').write_text(json.dumps(record, indent=2) + '\n')
    (audit / 'deployed.json').write_text(json.dumps(record, indent=2) + '\n')
    print(f'[ok] deployed and recorded snapshot {sha}')


if __name__ == '__main__':
    main()
