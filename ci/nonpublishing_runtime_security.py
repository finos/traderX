#!/usr/bin/env python3
"""Scan build-only runtimes without creating publication or deployment authorization."""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import subprocess
import uuid

from runtime_image_security import (DIGEST, SHA, UTC, command, policy_settings, fresh,
    database_age_limit, classify_scan, resolve_image, canonical_inventory, kubernetes_inventory)


def read(path):
    return json.loads(path.read_text())


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def identity(metadata):
    result = {key: os.environ['GITHUB_' + env] for key, env in
              [('snapshot', 'SHA'), ('repository', 'REPOSITORY'), ('run_id', 'RUN_ID'), ('run_attempt', 'RUN_ATTEMPT')]}
    result.update(state=metadata['stateId'], event=os.environ['GITHUB_EVENT_NAME'])
    if not SHA.fullmatch(result['snapshot']) or result['event'] not in ('push', 'workflow_dispatch'):
        raise ValueError('invalid exact-run scan identity')
    return result


def databases(root, reports, policy):
    cache = root / '.runtime-security-cache'
    cache.mkdir(exist_ok=True)
    scanner = ['docker', 'run', '--rm', '--platform', 'linux/amd64',
               '-v', str(cache) + ':/cache', '-v', '/var/run/docker.sock:/var/run/docker.sock',
               policy['runtimeImageScanner']['image']]
    evidence = {}
    for name, flag, path in [('vulnerability', '--download-db-only', 'db/metadata.json'),
                             ('java', '--download-java-db-only', 'java-db/metadata.json')]:
        result = command(*scanner, 'image', '--cache-dir', '/cache', '--no-progress', flag)
        (reports / (name + '-database.stderr.txt')).write_text(result.stderr)
        raw = (cache / path).read_bytes()
        data = json.loads(raw)
        fresh(data['UpdatedAt'], database_age_limit(policy, name))
        evidence[name] = {'UpdatedAt': data['UpdatedAt'], 'metadata_sha256': 'sha256:' + hashlib.sha256(raw).hexdigest()}
    return scanner, evidence


def scan(scanner, reference, output, index_image, disposition=None, local=False):
    container = 'traderx-security-' + uuid.uuid4().hex
    try:
        result = subprocess.run(scanner[:3] + ['--name', container] + scanner[3:] + [
            'image', '--cache-dir', '/cache', '--skip-db-update', '--skip-java-db-update',
            '--platform', 'linux/amd64', '--image-src', 'docker' if local else 'remote',
            '--scanners', 'vuln,secret', '--severity', 'HIGH,CRITICAL', '--exit-code', '1',
            '--format', 'json', '--no-progress', reference], capture_output=True, text=True, timeout=600)
        output.write_text(result.stdout)
        output.with_suffix('.stderr.txt').write_text(result.stderr)
        report = json.loads(result.stdout)
        status = classify_scan(report, result.returncode, index_image, disposition)
        if local and (report['Metadata'].get('ImageID') != reference
                      or report['Metadata'].get('ImageConfig', {}).get('architecture') != 'amd64'
                      or report['Metadata'].get('ImageConfig', {}).get('os') != 'linux'):
            raise ValueError('local scan report does not match inspected immutable configuration ID')
        return status, report
    except subprocess.TimeoutExpired as exc:
        output.with_suffix('.stderr.txt').write_text(str(exc.stderr or 'scanner timed out'))
        if exc.stdout:
            output.write_text(exc.stdout.decode(errors='replace') if isinstance(exc.stdout, bytes) else exc.stdout)
        raise
    finally:
        try:
            subprocess.run(['docker', 'rm', '-f', container], capture_output=True, timeout=15)
        except (OSError, subprocess.SubprocessError):
            output.with_suffix('.cleanup-warning.txt').write_text(container)


def module_record(root, metadata, module_name, reports, policy, expected):
    module, = [m for m in metadata['modules']['docker'] if m['imageName'] == module_name]
    inspected, = json.loads(command('docker', 'image', 'inspect', 'traderx-security/' + module_name + ':scan').stdout)
    image_id = inspected['Id']
    if not DIGEST.fullmatch(image_id) or inspected['Os'] != 'linux' or inspected['Architecture'] != 'amd64':
        raise ValueError('local build image lacks supported immutable configuration identity')
    scanner, db = databases(root, reports, policy)
    status, _ = scan(scanner, image_id, reports / 'scan.json', '', local=True)
    record = dict(expected, module=module, image_id=image_id, platform='linux/amd64',
                  scanner=policy['runtimeImageScanner'], databases=db, scanned_at=dt.datetime.now(UTC).isoformat(), **status)
    write(reports / 'local-image.json', record)
    if status['status'] != 'success':
        raise ValueError('local image scan blocked')


def validate_modules(artifacts, metadata, expected, policy):
    modules = {m['imageName']: m for m in metadata['modules']['docker']}
    if len(modules) != len(metadata['modules']['docker']):
        raise ValueError('duplicate local build module names')
    records = {}
    for path in artifacts.rglob('local-image.json'):
        record = read(path)
        name = record.get('module', {}).get('imageName')
        if name in records or name not in modules or record['module'] != modules[name]:
            raise ValueError('duplicate or mismatched local build module')
        if any(record.get(k) != v for k, v in expected.items()):
            raise ValueError('local scan evidence is from another snapshot/run/attempt')
        if (record.get('scanner') != policy['runtimeImageScanner'] or record.get('platform') != 'linux/amd64'
                or record.get('status') != 'success' or not DIGEST.fullmatch(record.get('image_id', ''))):
            raise ValueError('local scan evidence is incomplete or blocked')
        fresh(record.get('scanned_at'), policy['maxEvidenceAgeHours'])
        db = record.get('databases', {})
        if set(db) != {'java', 'vulnerability'}:
            raise ValueError('missing local database evidence')
        for kind, data in db.items():
            fresh(data.get('UpdatedAt'), database_age_limit(policy, kind))
            if not DIGEST.fullmatch(data.get('metadata_sha256', '')):
                raise ValueError('missing local database identity')
        raw = read(path.parent / 'scan.json')
        status = classify_scan(raw, 0, '')
        if (raw['Metadata'].get('ImageID') != record['image_id']
                or raw['Metadata'].get('ImageConfig', {}).get('architecture') != 'amd64'
                or raw['Metadata'].get('ImageConfig', {}).get('os') != 'linux' or status['status'] != 'success'
                or any(record.get(k) != status[k] for k in ('high', 'critical', 'fixed_findings'))):
            raise ValueError('local raw report disagrees with scan evidence')
        records[name] = record
    if set(records) != set(modules) or not modules:
        raise ValueError('missing local image scans')
    return records


def confined(root, path):
    result = (root / path).resolve()
    if not result.is_relative_to(root.resolve()):
        raise ValueError('runtime build path escapes snapshot')
    return result


def local_reference(record):
    return 'local-build/' + record['module']['imageName'] + '@' + record['image_id']


def inventory(root, metadata, records):
    modules = {name: r['module'] for name, r in records.items()}
    def render(runtime, prefix=''):
        target = confined(root, runtime['path'])
        if runtime['kind'] == 'compose':
            config = json.loads(command('docker', 'compose', '-f', str(target), 'config', '--format', 'json').stdout)
            entries = []
            for name, service in config.get('services', {}).items():
                if service.get('profiles'):
                    raise ValueError('runtime profile selection must be explicit')
                source = service.get('image')
                if service.get('platform') not in (None, 'linux/amd64'):
                    raise ValueError('runtime platform differs from scanned local builds')
                if isinstance(source, str) and source.startswith('local-build/'):
                    raise ValueError('reserved local evidence reference is not a runtime image')
                if 'build' in service:
                    if service.get('pull_policy') not in (None, 'build', 'never'):
                        raise ValueError('runtime can replace the scanned build with a registry pull')
                    build = service['build']
                    if not isinstance(build, dict) or set(build) - {'context', 'dockerfile'}:
                        raise ValueError('runtime build options differ from security matrix build')
                    context = confined(root, build['context'])
                    dockerfile = build.get('dockerfile', 'Dockerfile')
                    matches = [n for n, m in modules.items() if confined(root, m['directory']) == context and m['dockerfile'] == dockerfile]
                    if len(matches) != 1:
                        raise ValueError('runtime build has no unique scanned module')
                    source = local_reference(records[matches[0]])
                entries.append({'key': prefix + 'compose/' + name, 'source': source})
            entries = canonical_inventory(entries)
        elif runtime['kind'] == 'kubernetes':
            import yaml
            settings = read(root / 'ci/dependency-version-targets.json')['security']
            client = json.loads(command('kubectl', 'version', '--client', '-o', 'json').stdout)
            if client['clientVersion']['gitVersion'] != settings['kubernetesManifestRenderer']['version'] or yaml.__version__ != settings['kubernetesManifestParser']['version']:
                raise ValueError('runtime parser/renderer differs from canonical pins')
            aliases = {}
            for build in read(confined(root, runtime['buildPlan']))['images']:
                name, alias = build['name'], build['image']
                if (name not in modules or alias in aliases or modules[name]['directory'] != build['context']
                        or modules[name]['dockerfile'] != build['dockerfile']):
                    raise ValueError('runtime build plan differs from scanned module')
                aliases[alias] = local_reference(records[name])
            rendered = list(yaml.safe_load_all(command('kubectl', 'kustomize', str(target)).stdout))
            # Reject literal references to this helper's internal evidence namespace.
            if 'local-build/' in json.dumps(rendered):
                raise ValueError('reserved local evidence reference in Kubernetes runtime')
            entries = [dict(e, key=prefix + e['key']) for e in kubernetes_inventory(rendered, aliases)]
        else:
            raise ValueError('unsupported runtime selection')
        for i, companion in enumerate(runtime.get('companions', [])):
            if companion.get('companions'):
                raise ValueError('nested companions are unsupported')
            entries.extend(render(companion, prefix + 'companion/' + str(i) + '/'))
        return entries
    return canonical_inventory(render(metadata['runtime']))


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--module')
    parser.add_argument('--artifacts', type=Path)
    parser.add_argument('--reports', type=Path, default=Path('runtime-security-reports'))
    args = parser.parse_args()
    root = Path.cwd().resolve()
    metadata = read(root / 'ci/state-metadata.json')
    if metadata.get('isConvergence') is not False:
        raise ValueError('build-only diagnostics cannot authorize a publishing runtime')
    policy = policy_settings(read(root / 'ci/dependency-version-targets.json'))
    expected = identity(metadata)
    if command('git', 'rev-parse', 'HEAD').stdout.strip() != expected['snapshot']:
        raise ValueError('checkout differs from exact workflow snapshot')
    args.reports.mkdir(parents=True, exist_ok=False)
    summary = []
    entries = []
    try:
        if args.module:
            module_record(root, metadata, args.module, args.reports, policy, expected)
            return
        if args.artifacts is None:
            raise ValueError('missing exact-run local image scan artifacts')
        records = validate_modules(args.artifacts, metadata, expected, policy)
        entries = inventory(root, metadata, records)
        write(args.reports / 'inventory.json', entries)
        scanner, db = databases(root, args.reports, policy)
        local = {local_reference(r): r for r in records.values()}
        disposition = read(root / 'ci/state-009-grafana-fixed-findings.json')
        for i, entry in enumerate(entries):
            record = dict(entry, status='error')
            try:
                if entry['source'] in local:
                    record.update(local[entry['source']])
                else:
                    if entry['source'].startswith('local-build/'):
                        raise ValueError('runtime local alias has no independent build scan')
                    record.update(resolve_image(entry['source'], 'linux/amd64'))
                    status, _ = scan(scanner, record['image'], args.reports / f'{i}.json', record['index_image'], disposition)
                    record.update(status)
            except (OSError, subprocess.SubprocessError, ValueError, TypeError, KeyError) as exc:
                record['error'] = str(exc)
            summary.append(record)
            write(args.reports / 'summary.json', summary)
        if any(r['status'] != 'success' for r in summary):
            raise ValueError('build-only runtime scan blocked')
        write(args.reports / 'build-only-result.json', dict(expected, deployment_authorization=False,
              status='success', runtime=metadata['runtime'], databases=db, images=summary))
    except Exception as exc:
        completed = {r['key'] for r in summary}
        summary.extend(dict(e, status='error', error='scan not completed') for e in entries if e['key'] not in completed)
        write(args.reports / 'summary.json', summary)
        failure = {'error': str(exc), 'deployment_authorization': False}
        if isinstance(exc, subprocess.CalledProcessError):
            stderr = exc.stderr or ''
            failure['stderr'] = stderr.decode('utf-8', errors='replace') if isinstance(stderr, bytes) else stderr
            failure['returncode'] = exc.returncode
        write(args.reports / 'failure.json', failure)
        raise


if __name__ == '__main__':
    main()
