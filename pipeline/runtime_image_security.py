#!/usr/bin/env python3
"""Complete runtime image inventory, bounded scans, and deployment evidence."""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import uuid

DIGEST = re.compile(r'sha256:[0-9a-f]{64}$')
SHA = re.compile(r'[0-9a-f]{40}$')
UTC = dt.timezone.utc


def command(*args, timeout=600, **kwargs):
    return subprocess.run(args, check=True, capture_output=True, text=True, timeout=timeout, **kwargs)


def timestamp(value):
    if not isinstance(value, str):
        raise ValueError('missing timestamp')
    value = dt.datetime.fromisoformat(value.replace('Z', '+00:00'))
    if value.tzinfo is None:
        raise ValueError('timestamp must include timezone')
    return value


def fresh(value, hours, now=None):
    now = now or dt.datetime.now(UTC)
    age = now - timestamp(value)
    if age < -dt.timedelta(minutes=5) or age > dt.timedelta(hours=hours):
        raise ValueError('security evidence/database is stale or future-dated')


def image_repository(reference):
    if not isinstance(reference, str) or not reference or re.search(r'\s|\$|[{}]', reference):
        raise ValueError('missing or unresolved image reference')
    value = reference.split('@', 1)[0]
    if ':' in value.rsplit('/', 1)[-1]:
        value = value.rsplit(':', 1)[0]
    if not value or value.startswith(('traderx-local/', 'traderx-remediation/', 'traderx/')):
        raise ValueError('unresolved local image alias')
    return value


def canonical_inventory(entries):
    if not entries or len({e['key'] for e in entries}) != len(entries):
        raise ValueError('empty or duplicate runtime inventory')
    for entry in entries:
        image_repository(entry['source'])
    return sorted(entries, key=lambda e: e['key'])


def inventory_hash(entries):
    return hashlib.sha256(json.dumps(canonical_inventory(entries), sort_keys=True,
                                     separators=(',', ':')).encode()).hexdigest()


def compose_inventory(config):
    services = config.get('services')
    if not isinstance(services, dict) or not services:
        raise ValueError('missing Compose service inventory')
    entries = []
    for name, service in services.items():
        if not isinstance(service, dict) or service.get('profiles'):
            raise ValueError('runtime profile selection must be explicit before scanning')
        entries.append({'key': 'compose/' + name, 'source': service.get('image')})
    return canonical_inventory(entries)


def kubernetes_inventory(documents, aliases):
    entries = []
    def visit(item, path, identity):
        if isinstance(item, dict):
            if item.get('kind') == 'List':
                for child in item.get('items', []):
                    add(child)
                return
            for key, value in item.items():
                if key in ('containers', 'initContainers', 'ephemeralContainers'):
                    if not isinstance(value, list) or not value:
                        raise ValueError('invalid Kubernetes container list')
                    for container in value:
                        if not isinstance(container, dict) or not container.get('name'):
                            raise ValueError('invalid Kubernetes container')
                        image = container.get('image')
                        entries.append({'key': identity + '/' + '/'.join(path + [key, container['name']]),
                                        'source': aliases.get(image, image)})
                else:
                    visit(value, path + [key], identity)
        elif isinstance(item, list):
            for index, child in enumerate(item):
                visit(child, path + [str(index)], identity)
    def add(doc):
        if not isinstance(doc, dict):
            raise ValueError('invalid Kubernetes document')
        meta = doc.get('metadata', {})
        identity = '/'.join([meta.get('namespace', 'default'), doc.get('kind', ''), meta.get('name', '')])
        visit(doc, [], identity)
    for doc in documents:
        if doc is not None:
            add(doc)
    return canonical_inventory(entries)


def runtime_inventory(root, metadata, snapshot):
    entries = primary_runtime_inventory(root, metadata, snapshot)
    companions = metadata['runtime'].get('companions', [])
    if not isinstance(companions, list):
        raise ValueError('invalid companion runtime inventory')
    for index, companion in enumerate(companions):
        if companion.get('kind') != 'compose' or companion.get('companions'):
            raise ValueError('unsupported companion runtime')
        nested = dict(metadata, runtime=companion)
        entries.extend(dict(entry, key='companion/' + str(index) + '/' + entry['key'])
                       for entry in primary_runtime_inventory(root, nested, snapshot))
    return canonical_inventory(entries)


def primary_runtime_inventory(root, metadata, snapshot):
    runtime = metadata['runtime']
    target = (root / runtime['path']).resolve()
    if not target.is_relative_to(root.resolve()):
        raise ValueError('runtime path escapes snapshot')
    if runtime['kind'] == 'compose':
        config = json.loads(command('docker', 'compose', '-f', str(target), 'config', '--format', 'json',
                                    env=dict(os.environ, TRADERX_IMAGE_TAG=snapshot)).stdout)
        return compose_inventory(config)
    if runtime['kind'] == 'kubernetes':
        import yaml
        settings = json.loads((root / 'ci/dependency-version-targets.json').read_text())['security']
        client = json.loads(command('kubectl', 'version', '--client', '-o', 'json').stdout)
        if client['clientVersion']['gitVersion'] != settings['kubernetesManifestRenderer']['version'] or yaml.__version__ != settings['kubernetesManifestParser']['version']:
            raise ValueError('runtime inventory parser/renderer differs from canonical tool pins')
        build_plan = json.loads((root / runtime['buildPlan']).read_text())
        aliases = {}
        for entry in build_plan['images']:
            alias = entry['image']
            if alias in aliases:
                raise ValueError('duplicate Kubernetes build alias')
            aliases[alias] = 'ghcr.io/finos/' + metadata['convergenceNamespace'] + '/' + entry['name'] + ':' + snapshot
        rendered = command('kubectl', 'kustomize', str(target)).stdout
        return kubernetes_inventory(list(yaml.safe_load_all(rendered)), aliases)
    raise ValueError('unsupported active runtime')


def policy_settings(targets):
    policy = targets['security']
    scanner = policy['runtimeImageScanner']
    if not DIGEST.fullmatch(scanner['image'].split('@')[-1]) or not scanner['version']:
        raise ValueError('scanner must be versioned and digest pinned')
    platforms = policy['supportedPlatforms']
    # Explicitly constrain currently supported deployment, rather than implying untested multiarch coverage.
    if platforms != ['linux/amd64']:
        raise ValueError('unsupported runtime security platform policy')
    for key, limit in [('maxEvidenceAgeHours', 24), ('maxDatabaseAgeHours', 24), ('maxJavaDatabaseAgeHours', 96)]:
        if not isinstance(policy[key], (int, float)) or not 0 < policy[key] <= limit:
            raise ValueError('security freshness policy exceeds its permitted bound')
    return policy


def database_age_limit(policy, name):
    # Java DB maps archive hashes to Maven coordinates; CVE data remains <=24h.
    return policy['maxJavaDatabaseAgeHours' if name == 'java' else 'maxDatabaseAgeHours']


def accepted_disposition(finding, index_image, policy, now=None):
    if not policy or index_image != policy.get('image'):
        return False
    if policy.get('approved') is not True:
        raise ValueError('unapproved finding disposition')
    if timestamp(policy['expires']) <= (now or dt.datetime.now(UTC)):
        raise ValueError('expired finding disposition')
    return (finding.get('PkgName') == policy['package']
            and finding.get('InstalledVersion') == policy['installed_version']
            and finding.get('VulnerabilityID') in policy['fixed_findings'])


def classify_scan(report, returncode, index_image, disposition=None):
    if (returncode not in (0, 1) or not isinstance(report, dict)
            or report.get('SchemaVersion') != 2 or not isinstance(report.get('Results'), list)
            or not isinstance(report.get('Metadata'), dict)):
        raise ValueError('scanner failed or returned malformed report')
    high = critical = 0
    fixed = []
    for result in report['Results']:
        if not isinstance(result, dict):
            raise ValueError('malformed scan target')
        for kind in ('Vulnerabilities', 'Secrets'):
            findings = result.get(kind, [])
            if not isinstance(findings, list):
                raise ValueError('malformed findings')
            for finding in findings:
                if not isinstance(finding, dict) or finding.get('Severity') not in ('UNKNOWN', 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'):
                    raise ValueError('malformed finding severity')
                if finding['Severity'] not in ('HIGH', 'CRITICAL'):
                    continue
                if kind == 'Vulnerabilities' and accepted_disposition(finding, index_image, disposition):
                    fixed.append({k: finding.get(k) for k in ('VulnerabilityID', 'PkgName', 'InstalledVersion', 'Severity')})
                elif finding['Severity'] == 'HIGH':
                    high += 1
                else:
                    critical += 1
    if returncode == 1 and not (high or critical or fixed):
        raise ValueError('scanner failure without reported findings')
    return {'status': 'findings' if high or critical else 'success',
            'high': high, 'critical': critical, 'fixed_findings': fixed}


def validate_published(records, metadata, snapshot, run_id, attempt):
    expected = {'ghcr.io/finos/' + metadata['convergenceNamespace'] + '/' + m['imageName']
                for m in metadata['modules']['docker']}
    images = {}
    for record in records:
        image = record.get('image')
        if image in images or image not in expected or record.get('snapshot') != snapshot or str(record.get('run_id')) != str(run_id) or str(record.get('run_attempt')) != str(attempt) or not DIGEST.fullmatch(record.get('digest', '')):
            raise ValueError('published image evidence is incomplete, duplicated, or from another run')
        images[image] = image + '@' + record['digest']
    if set(images) != expected or not expected:
        raise ValueError('missing published image evidence')
    return images


def validate_published_binding(locks, published):
    for lock in locks.values():
        repository = image_repository(lock['source'])
        if repository.startswith('ghcr.io/finos/') and repository not in published:
            raise ValueError('runtime application lacks independently verified publication')
        if repository in published and lock['index_image'] != published[repository]:
            raise ValueError('runtime scan does not match published application digest')


def platform_digest(raw_manifest, index_digest, platform):
    if not isinstance(raw_manifest, str) or len(raw_manifest) > 2 * 1024 * 1024:
        raise ValueError('missing or oversized OCI manifest proof')
    if 'sha256:' + hashlib.sha256(raw_manifest.encode()).hexdigest() != index_digest:
        raise ValueError('OCI manifest proof does not match the authorized index digest')
    manifest = json.loads(raw_manifest)
    if not isinstance(manifest, dict) or manifest.get('schemaVersion') != 2:
        raise ValueError('unsupported OCI manifest schema')
    manifests = manifest.get('manifests')
    if manifests is not None:
        if not isinstance(manifests, list):
            raise ValueError('invalid OCI index')
        os_name, arch = platform.split('/')
        matches = [m for m in manifests if isinstance(m, dict) and isinstance(m.get('platform'), dict) and m['platform'].get('os') == os_name
                   and m.get('platform', {}).get('architecture') == arch
                   and not m.get('platform', {}).get('variant')]
        if len(matches) != 1:
            raise ValueError('missing or ambiguous platform image')
        digest = matches[0].get('digest', '')
    else:
        # For a single manifest the parent and child are identical; the CI pull
        # additionally inspects its architecture before emitting authorization.
        if not isinstance(manifest.get('config'), dict) or not DIGEST.fullmatch(manifest['config'].get('digest', '')):
            raise ValueError('invalid single-platform image manifest')
        digest = index_digest
    if not DIGEST.fullmatch(digest):
        raise ValueError('invalid platform digest')
    return digest


def verify_image_binding(record):
    index = record['index_image'].rsplit('@', 1)[1]
    expected = platform_digest(record.get('index_manifest'), index, record['platform'])
    if record['image'].rsplit('@', 1)[1] != expected:
        raise ValueError('scanned image is not the authorized index platform child')


def resolve_image(reference, platform):
    descriptor = json.loads(command('docker', 'buildx', 'imagetools', 'inspect', reference,
                                    '--format', '{{json .Manifest}}').stdout)
    index_digest = descriptor.get('digest', '')
    if not DIGEST.fullmatch(index_digest):
        raise ValueError('registry did not return an immutable image descriptor')
    if '@' in reference and reference.rsplit('@', 1)[1] != index_digest:
        raise ValueError('registry resolved a different digest')
    repo = image_repository(reference)
    index_image = repo + '@' + index_digest
    raw = command('docker', 'buildx', 'imagetools', 'inspect', index_image, '--raw').stdout
    digest = platform_digest(raw, index_digest, platform)
    pinned = repo + '@' + digest
    command('docker', 'pull', '--platform', platform, pinned)
    actual = json.loads(command('docker', 'image', 'inspect', pinned).stdout)
    os_name, arch = platform.split('/')
    if len(actual) != 1 or actual[0].get('Os') != os_name or actual[0].get('Architecture') != arch:
        raise ValueError('pulled image platform differs from authorization')
    return {'image': pinned, 'index_image': index_image, 'index_manifest': raw, 'platform': platform}


def validate_lock(lock, metadata, entries, repository, snapshot, run_id, attempt, settings, now=None, disposition=None):
    policy = policy_settings(settings)
    if (lock.get('schema_version') != 1 or lock.get('repository') != repository
            or lock.get('state') != metadata['stateId'] or lock.get('snapshot') != snapshot
            or lock.get('event') != 'push' or str(lock.get('run_id')) != str(run_id)
            or str(lock.get('run_attempt')) != str(attempt)
            or lock.get('scanner') != policy['runtimeImageScanner']
            or lock.get('platforms') != policy['supportedPlatforms']
            or lock.get('inventory_tools', {}) != ({k: policy[k] for k in ('kubernetesManifestParser', 'kubernetesManifestRenderer')} if metadata['runtime']['kind'] == 'kubernetes' else {})
            or lock.get('runtime') != metadata['runtime']
            or lock.get('inventory_sha256') != inventory_hash(entries)):
        raise ValueError('runtime authorization does not match exact snapshot/run/platform/inventory')
    fresh(lock.get('created_at'), policy['maxEvidenceAgeHours'], now)
    databases = lock.get('databases')
    if not isinstance(databases, dict) or set(databases) != {'vulnerability', 'java'}:
        raise ValueError('missing scanner database evidence')
    for name, database in databases.items():
        fresh(database.get('UpdatedAt'), database_age_limit(policy, name), now)
        if not DIGEST.fullmatch(database.get('metadata_sha256', '')):
            raise ValueError('missing database identity')
    records = lock.get('images')
    if not isinstance(records, list) or len(records) != len(entries):
        raise ValueError('runtime evidence image count differs')
    expected = {e['key']: e['source'] for e in entries}
    seen = set()
    for record in records:
        key = record.get('key')
        if (key in seen or key not in expected or record.get('source') != expected[key]
                or record.get('platform') != 'linux/amd64' or record.get('status') != 'success'
                or record.get('high') != 0 or record.get('critical') != 0):
            raise ValueError('missing, duplicated, blocked or substituted runtime image')
        for field in ('image', 'index_image'):
            ref = record.get(field, '')
            if '@' not in ref or not DIGEST.fullmatch(ref.rsplit('@', 1)[1]) or image_repository(ref) != image_repository(record['source']):
                raise ValueError('invalid authorized image digest/repository')
        if '@' in record['source'] and record['source'] != record['index_image']:
            raise ValueError('authorized digest differs from the pinned runtime source')
        verify_image_binding(record)
        fresh(record.get('scanned_at'), policy['maxEvidenceAgeHours'], now)
        if not isinstance(record.get('fixed_findings'), list):
            raise ValueError('missing disposition audit')
        for finding in record['fixed_findings']:
            if not accepted_disposition(finding, record['index_image'], disposition, now):
                raise ValueError('runtime evidence contains an unauthorized disposition')
        seen.add(key)
    return {r['key']: r for r in records}


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--root', type=Path, default=Path.cwd())
    parser.add_argument('--published', type=Path, required=True)
    parser.add_argument('--reports', type=Path, default=Path('runtime-security-reports'))
    parser.add_argument('--output', type=Path, default=Path('runtime-lock.json'))
    args = parser.parse_args()
    args.output.unlink(missing_ok=True)
    root = args.root.resolve()
    metadata = json.loads((root / 'ci/state-metadata.json').read_text())
    settings = json.loads((root / 'ci/dependency-version-targets.json').read_text())
    policy = policy_settings(settings)
    snapshot, repository = os.environ['GITHUB_SHA'], os.environ['GITHUB_REPOSITORY']
    run_id, attempt = os.environ['GITHUB_RUN_ID'], os.environ['GITHUB_RUN_ATTEMPT']
    if not SHA.fullmatch(snapshot) or os.environ.get('GITHUB_EVENT_NAME') != 'push':
        raise ValueError('runtime authorization requires an exact snapshot push')
    args.reports.mkdir(parents=True, exist_ok=False)
    summary = []
    entries = []
    try:
        published = validate_published([json.loads(p.read_text()) for p in args.published.rglob('image.json')],
                                       metadata, snapshot, run_id, attempt)
        entries = runtime_inventory(root, metadata, snapshot)
        app_repositories = {image_repository(e['source']) for e in entries if e['source'].startswith('ghcr.io/finos/')}
        if not app_repositories.issubset(published):
            raise ValueError('active runtime contains an unpublished application image')
        (args.reports / 'inventory.json').write_text(json.dumps(entries, indent=2) + '\n')
        cache = root / '.runtime-security-cache'
        cache.mkdir(exist_ok=True)
        scanner = policy['runtimeImageScanner']['image']
        base_command = ['docker', 'run', '--rm', '--platform', 'linux/amd64', '--user', f'{os.getuid()}:{os.getgid()}', '-v', str(cache) + ':/cache', scanner]
        databases = {}
        for name, flag, relative in [('vulnerability', '--download-db-only', 'db/metadata.json'),
                                      ('java', '--download-java-db-only', 'java-db/metadata.json')]:
            result = command(*base_command, 'image', '--cache-dir', '/cache', '--no-progress', flag)
            (args.reports / (name + '-database.stderr.txt')).write_text(result.stderr)
            raw = (cache / relative).read_bytes()
            data = json.loads(raw)
            fresh(data.get('UpdatedAt'), database_age_limit(policy, name))
            databases[name] = {'UpdatedAt': data['UpdatedAt'], 'metadata_sha256': 'sha256:' + hashlib.sha256(raw).hexdigest()}
        disposition_file = root / 'ci/state-009-grafana-fixed-findings.json'
        disposition = json.loads(disposition_file.read_text()) if disposition_file.exists() else None
        for index, entry in enumerate(entries):
            record = dict(entry, status='error', high=0, critical=0, fixed_findings=[])
            container = 'traderx-security-' + uuid.uuid4().hex
            try:
                reference = published.get(image_repository(entry['source']), entry['source'])
                record.update(resolve_image(reference, 'linux/amd64'))
                result = subprocess.run(base_command[:3] + ['--name', container] + base_command[3:] + [
                    'image', '--cache-dir', '/cache', '--skip-db-update', '--skip-java-db-update',
                    '--platform', 'linux/amd64', '--scanners', 'vuln,secret', '--severity', 'HIGH,CRITICAL',
                    '--exit-code', '1', '--format', 'json', '--no-progress', record['image']],
                    capture_output=True, text=True, timeout=600)
                (args.reports / f'{index}.json').write_text(result.stdout)
                (args.reports / f'{index}.stderr.txt').write_text(result.stderr)
                record.update(classify_scan(json.loads(result.stdout), result.returncode, record['index_image'], disposition))
                record['scanned_at'] = dt.datetime.now(UTC).isoformat()
            except (OSError, subprocess.SubprocessError, ValueError, TypeError, KeyError) as exc:
                record['error'] = str(exc)
                diagnostic = getattr(exc, 'stderr', None)
                if diagnostic:
                    (args.reports / f'{index}.stderr.txt').write_text(diagnostic.decode(errors='replace') if isinstance(diagnostic, bytes) else diagnostic)
            finally:
                try:
                    subprocess.run(['docker', 'rm', '-f', container], capture_output=True, timeout=15)
                except (OSError, subprocess.SubprocessError):
                    record['cleanup_warning'] = container
                summary.append(record)
                (args.reports / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        if any(r['status'] != 'success' for r in summary):
            raise ValueError('runtime image security blocked; inspect complete summary')
        lock = {'schema_version': 1, 'repository': repository, 'state': metadata['stateId'],
                'snapshot': snapshot, 'event': 'push', 'run_id': run_id, 'run_attempt': attempt,
                'created_at': dt.datetime.now(UTC).isoformat(), 'runtime': metadata['runtime'],
                'platforms': policy['supportedPlatforms'], 'scanner': policy['runtimeImageScanner'],
                'databases': databases, 'inventory_tools': ({k: policy[k] for k in ('kubernetesManifestParser', 'kubernetesManifestRenderer')} if metadata['runtime']['kind'] == 'kubernetes' else {}), 'inventory_sha256': inventory_hash(entries), 'images': summary}
        validate_lock(lock, metadata, entries, repository, snapshot, run_id, attempt, settings, disposition=disposition)
        args.output.write_text(json.dumps(lock, indent=2) + '\n')
    except Exception as exc:
        completed = {r['key'] for r in summary}
        summary.extend(dict(e, status='error', error='scan not completed: ' + str(exc)) for e in entries if e['key'] not in completed)
        (args.reports / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        if isinstance(exc, subprocess.CalledProcessError):
            (args.reports / 'failure.stderr.txt').write_text(exc.stderr or '')
        (args.reports / 'failure.json').write_text(json.dumps({'error': str(exc), 'completed_images': len(summary)}) + '\n')
        raise


if __name__ == '__main__':
    main()
