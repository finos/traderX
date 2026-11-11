#!/usr/bin/env python3
"""Adversarial tests for complete runtime image authorization."""
import copy
import datetime as dt
import importlib.util
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'pipeline'))
import runtime_image_security as security

SHA = 'a' * 40
CHILD = 'sha256:' + 'c' * 64
MANIFEST = json.dumps({'schemaVersion': 2, 'manifests': [{'digest': CHILD, 'platform': {'os': 'linux', 'architecture': 'amd64'}}]})
DIGEST = 'sha256:' + hashlib.sha256(MANIFEST.encode()).hexdigest()
IMAGE = 'ghcr.io/finos/traderx-c2/ingress'
NOW = dt.datetime(2026, 11, 11, 12, tzinfo=dt.timezone.utc)
SETTINGS = {'security': {'runtimeImageScanner': {'image': 'aquasec/trivy:0.76.2@' + DIGEST, 'version': '0.76.2'},
                         'supportedPlatforms': ['linux/amd64'], 'maxEvidenceAgeHours': 24, 'maxDatabaseAgeHours': 24, 'maxJavaDatabaseAgeHours': 96}}
METADATA = {'stateId': '009-order-management-matcher', 'convergenceNamespace': 'traderx-c2',
            'modules': {'docker': [{'imageName': 'ingress'}]},
            'runtime': {'kind': 'compose', 'path': 'runtime/ghcr/009-order-management-matcher/docker-compose.ghcr.yml'}}
ENTRIES = [{'key': 'compose/ingress', 'source': IMAGE + ':' + SHA}]


def lock_fixture(now=NOW):
    stamp = now.isoformat()
    return {'schema_version': 1, 'repository': 'finos/traderX', 'state': METADATA['stateId'], 'snapshot': SHA,
            'event': 'push', 'run_id': '12', 'run_attempt': '2', 'created_at': stamp,
            'runtime': METADATA['runtime'], 'platforms': ['linux/amd64'],
            'scanner': SETTINGS['security']['runtimeImageScanner'],
            'databases': {name: {'UpdatedAt': stamp, 'metadata_sha256': DIGEST} for name in ['java', 'vulnerability']},
            'inventory_sha256': security.inventory_hash(ENTRIES),
            'images': [dict(ENTRIES[0], image=IMAGE + '@' + CHILD, index_image=IMAGE + '@' + DIGEST,
                            platform='linux/amd64', status='success', high=0, critical=0,
                            fixed_findings=[], scanned_at=stamp, index_manifest=MANIFEST)]}


def validate(lock, entries=ENTRIES):
    return security.validate_lock(lock, METADATA, entries, 'finos/traderX', SHA, 12, 2, SETTINGS, now=NOW)


class TimestampTests(unittest.TestCase):
    def test_trivy_nanoseconds_and_fraction_lengths(self):
        stamp = security.timestamp('2026-11-10T19:01:23.081219346+00:00')
        self.assertEqual(stamp, dt.datetime(2026, 11, 10, 19, 1, 23, 81219, tzinfo=security.UTC))
        self.assertEqual(security.timestamp('2026-11-10T19:01:23.081219346Z', round_up=True),
                         stamp + dt.timedelta(microseconds=1))
        for fraction in ['', '.1', '.12', '.123', '.1234', '.12345', '.123456', '.123456000']:
            value = security.timestamp('2026-11-11T12:00:00' + fraction + 'Z')
            expected = int(fraction[1:7].ljust(6, '0')) if fraction else 0
            self.assertEqual(value.microsecond, expected)

    def test_offsets_and_invalid_timezone(self):
        for stamp in ['2026-11-11T17:30:00+05:30', '2026-11-11T08:00:00-04:00']:
            self.assertEqual(security.timestamp(stamp), NOW)
        for stamp in [None, '2026-11-11T12:00:00', '2026-11-11T12:00:00+24:00',
                      '2026-11-11T12:00:00+00:60', '2026-11-11T12:00:00+01',
                      '2026-11-11T12:00:00Zjunk', '2026-11-11T12:00:00.+00:00',
                      '2026-11-11T25:00:00Z', '2026-02-30T12:00:00Z']:
            with self.subTest(stamp=stamp), self.assertRaises(ValueError):
                security.timestamp(stamp)

    def test_freshness_nanosecond_boundaries_fail_closed(self):
        for stamp in ['2026-11-10T12:00:00Z', '2026-11-10T12:00:00.000000001Z',
                      '2026-11-11T12:05:00.000000000Z', '2026-11-11T12:04:59.999999999Z']:
            security.fresh(stamp, 24, NOW)
        for stamp in ['2026-11-10T11:59:59.999999999Z', '2026-11-11T12:05:00.000000001Z']:
            with self.subTest(stamp=stamp), self.assertRaises(ValueError):
                security.fresh(stamp, 24, NOW)

    def test_expiry_floor_does_not_extend_disposition(self):
        finding = {'PkgName': 'example', 'InstalledVersion': '1', 'VulnerabilityID': 'CVE-2026-1'}
        policy = {'image': IMAGE, 'approved': True, 'package': 'example', 'installed_version': '1',
                  'fixed_findings': ['CVE-2026-1'], 'expires': '2026-11-11T12:00:00.000000001Z'}
        self.assertTrue(security.accepted_disposition(finding, IMAGE, policy, NOW - dt.timedelta(microseconds=1)))
        for expiry in ['2026-11-11T12:00:00Z', '2026-11-11T12:00:00.000000001Z', '2026-11-11T11:59:59.999999999Z']:
            with self.subTest(expiry=expiry), self.assertRaises(ValueError):
                security.accepted_disposition(finding, IMAGE, dict(policy, expires=expiry), NOW)


class InventoryTests(unittest.TestCase):
    def test_compose_requires_every_active_service_to_have_resolved_image(self):
        self.assertEqual(security.compose_inventory({'services': {'ingress': {'image': IMAGE + ':' + SHA}}}), ENTRIES)
        for config in [{}, {'services': {}}, {'services': {'x': {'build': '.'}}},
                       {'services': {'x': {'image': '${IMAGE}'}}},
                       {'services': {'x': {'image': 'traderx/local:latest'}}},
                       {'services': {'x': {'image': 'alpine:3', 'profiles': ['debug']}}}]:
            with self.subTest(config=config), self.assertRaises(ValueError):
                security.compose_inventory(config)

    def test_kubernetes_includes_init_sidecar_daemonset_job_and_list(self):
        pod = {'containers': [{'name': 'app', 'image': 'local-app'}, {'name': 'sidecar', 'image': 'sidecar:2'}],
               'initContainers': [{'name': 'migrate', 'image': 'init:1'}]}
        docs = [{'kind': 'Deployment', 'metadata': {'name': 'app', 'namespace': 'demo'}, 'spec': {'template': {'spec': pod}}},
                {'kind': 'DaemonSet', 'metadata': {'name': 'logs'}, 'spec': {'template': {'spec': {'containers': [{'name': 'log', 'image': 'vector:1'}]}}}},
                {'kind': 'List', 'items': [{'kind': 'CronJob', 'metadata': {'name': 'nightly'}, 'spec': {'jobTemplate': {'spec': {'template': {'spec': {'containers': [{'name': 'backup', 'image': 'postgres:16'}]}}}}}}]}]
        entries = security.kubernetes_inventory(docs, {'local-app': IMAGE + ':' + SHA})
        self.assertEqual(len(entries), 5)
        self.assertTrue(any('/initContainers/migrate' in e['key'] for e in entries))
        self.assertTrue(any(e['source'] == IMAGE + ':' + SHA for e in entries))
        with self.assertRaises(ValueError):
            security.kubernetes_inventory(docs + docs, {'local-app': IMAGE + ':' + SHA})

    def test_local_build_alias_does_not_silently_become_registry_image(self):
        docs = [{'kind': 'Pod', 'metadata': {'name': 'x'}, 'spec': {'containers': [{'name': 'x', 'image': 'traderx/x:local'}]}}]
        with self.assertRaises(ValueError):
            security.kubernetes_inventory(docs, {})

    def test_companion_inventory_is_required_and_separately_identified(self):
        metadata = dict(METADATA, runtime=dict(METADATA['runtime'], companions=[{'kind': 'compose', 'path': 'sail/docker-compose.yml'}]))
        companion = [{'key': 'compose/sail', 'source': 'node:22-bookworm'}]
        with patch.object(security, 'primary_runtime_inventory', side_effect=[ENTRIES.copy(), companion]):
            entries = security.runtime_inventory(Path('/snapshot'), metadata, SHA)
        self.assertEqual(len(entries), 2)
        self.assertTrue(any(e['key'] == 'companion/0/compose/sail' for e in entries))
        with patch.object(security, 'primary_runtime_inventory', side_effect=[ENTRIES.copy(), ValueError('missing companion')]):
            with self.assertRaises(ValueError):
                security.runtime_inventory(Path('/snapshot'), metadata, SHA)

    def test_companion_alias_requires_publishing_metadata_and_build_module(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'plan.json').write_text(json.dumps({'images': [{'name': 'sail', 'image': 'traderx-remediation/sail:014'}]}))
            runtime = {'kind': 'compose', 'path': 'compose.yml', 'buildPlan': 'plan.json'}
            metadata = dict(METADATA, runtime=runtime, isConvergence=True, modules={'docker': [{'imageName': 'sail'}]})
            config = {'services': {'sail': {'image': 'traderx-remediation/sail:014'}}}
            with patch.object(security, 'command', return_value=type('Result', (), {'stdout': json.dumps(config)})()):
                entries = security.runtime_inventory(root, metadata, SHA)
                self.assertEqual(entries[0]['source'], 'ghcr.io/finos/traderx-c2/sail:' + SHA)
                for change in [{'isConvergence': False}, {'modules': {'docker': []}}]:
                    with self.assertRaises(ValueError):
                        security.runtime_inventory(root, metadata | change, SHA)

    def test_inventory_hash_detects_added_image_and_reference_change(self):
        baseline = security.inventory_hash(ENTRIES)
        self.assertNotEqual(baseline, security.inventory_hash(ENTRIES + [{'key': 'compose/db', 'source': 'postgres:16'}]))
        self.assertNotEqual(baseline, security.inventory_hash([dict(ENTRIES[0], source=IMAGE + ':other')]))


class EvidenceTests(unittest.TestCase):
    def test_valid_lock(self):
        self.assertEqual(set(validate(lock_fixture())), {'compose/ingress'})

    def test_wrong_identity_run_attempt_platform_scanner_and_inventory_fail(self):
        changes = {'schema_version': 2, 'repository': 'other/repo', 'state': '004-other', 'snapshot': 'd' * 40,
                   'event': 'workflow_dispatch', 'run_id': '13', 'run_attempt': '1', 'platforms': ['linux/arm64'],
                   'scanner': {}, 'runtime': {'kind': 'kubernetes'}, 'inventory_sha256': 'wrong'}
        for key, value in changes.items():
            with self.subTest(key=key), self.assertRaises(ValueError):
                validate(lock_fixture() | {key: value})

    def test_missing_duplicate_unverified_or_blocked_image_fails(self):
        for replacement in [[], lock_fixture()['images'] * 2,
                            [lock_fixture()['images'][0] | {'key': 'compose/other'}],
                            [lock_fixture()['images'][0] | {'source': IMAGE + ':moved'}],
                            [lock_fixture()['images'][0] | {'image': 'other@' + CHILD}],
                            [lock_fixture()['images'][0] | {'image': IMAGE + ':latest'}],
                            [lock_fixture()['images'][0] | {'high': 1}],
                            [lock_fixture()['images'][0] | {'status': 'skipped'}],
                            [lock_fixture()['images'][0] | {'platform': 'linux/arm64'}]]:
            with self.subTest(replacement=replacement), self.assertRaises(ValueError):
                validate(lock_fixture() | {'images': replacement})

    def test_stale_future_missing_database_and_scan_time_fail(self):
        for delta in [dt.timedelta(hours=-25), dt.timedelta(minutes=6)]:
            stale = (NOW + delta).isoformat()
            for field in ['created_at', 'database', 'scan']:
                bad = lock_fixture()
                if field == 'database': bad['databases']['vulnerability']['UpdatedAt'] = stale
                elif field == 'scan': bad['images'][0]['scanned_at'] = stale
                else: bad[field] = stale
                with self.subTest(delta=delta, field=field), self.assertRaises(ValueError): validate(bad)
        for databases in [{}, {'vulnerability': lock_fixture()['databases']['vulnerability']}]:
            with self.assertRaises(ValueError): validate(lock_fixture() | {'databases': databases})

    def test_database_freshness_separates_mapping_from_vulnerability_data(self):
        for hours in [25, 72, 96]:
            lock = lock_fixture()
            lock['databases']['java']['UpdatedAt'] = (NOW - dt.timedelta(hours=hours)).isoformat()
            validate(lock)
        for name, hours in [('java', 97), ('vulnerability', 25)]:
            lock = lock_fixture()
            lock['databases'][name]['UpdatedAt'] = (NOW - dt.timedelta(hours=hours)).isoformat()
            with self.subTest(database=name), self.assertRaises(ValueError): validate(lock)
        for name in ['java', 'vulnerability']:
            lock = lock_fixture()
            lock['databases'][name]['UpdatedAt'] = (NOW + dt.timedelta(minutes=6)).isoformat()
            with self.assertRaises(ValueError): validate(lock)
        for key, value in [('maxJavaDatabaseAgeHours', 97), ('maxDatabaseAgeHours', 25)]:
            settings = copy.deepcopy(SETTINGS)
            settings['security'][key] = value
            with self.assertRaises(ValueError): security.policy_settings(settings)

    def test_runtime_app_requires_matching_independent_publication(self):
        locks = validate(lock_fixture())
        security.validate_published_binding(locks, {IMAGE: IMAGE + '@' + DIGEST})
        for published in [{}, {IMAGE: IMAGE + '@sha256:' + 'f' * 64}]:
            with self.assertRaises(ValueError):
                security.validate_published_binding(locks, published)

    def test_tagged_pinned_source_accepts_same_repository_and_digest(self):
        entries = [dict(ENTRIES[0], source=IMAGE + ':stable@' + DIGEST)]
        lock = lock_fixture()
        lock['inventory_sha256'] = security.inventory_hash(entries)
        lock['images'][0]['source'] = entries[0]['source']
        validate(lock, entries)

    def test_pinned_source_digest_cannot_be_substituted_with_same_repository(self):
        entries = [dict(ENTRIES[0], source=IMAGE + '@sha256:' + 'f' * 64)]
        lock = lock_fixture()
        lock['inventory_sha256'] = security.inventory_hash(entries)
        lock['images'][0]['source'] = entries[0]['source']
        with self.assertRaises(ValueError): validate(lock, entries)

    def test_parent_child_binding_requires_digest_verified_platform_manifest(self):
        for change in [{'index_manifest': '{}'}, {'image': IMAGE + '@' + ('sha256:' + 'f' * 64)},
                       {'index_image': IMAGE + '@' + ('sha256:' + 'f' * 64)},
                       {'index_manifest': MANIFEST.replace('amd64', 'arm64')}]:
            lock = lock_fixture()
            lock['images'][0].update(change)
            with self.subTest(change=change), self.assertRaises(ValueError): validate(lock)
        ambiguous = json.dumps({'schemaVersion': 2, 'manifests': json.loads(MANIFEST)['manifests'] * 2})
        with self.assertRaises(ValueError):
            security.platform_digest(ambiguous, 'sha256:' + hashlib.sha256(ambiguous.encode()).hexdigest(), 'linux/amd64')

    def test_unknown_disposition_cannot_be_forged_in_success_evidence(self):
        bad = lock_fixture()
        bad['images'][0]['fixed_findings'] = [{'VulnerabilityID': 'CVE-fake'}]
        with self.assertRaises(ValueError): validate(bad)

    def test_published_images_bound_to_snapshot_attempt_and_complete_set(self):
        record = {'image': IMAGE, 'digest': DIGEST, 'snapshot': SHA, 'run_id': '12', 'run_attempt': '2'}
        self.assertEqual(security.validate_published([record], METADATA, SHA, 12, 2), {IMAGE: IMAGE + '@' + DIGEST})
        for records in [[], [record, record], [record | {'run_attempt': '1'}], [record | {'snapshot': 'd' * 40}],
                        [record | {'image': 'other'}], [record | {'digest': 'latest'}]]:
            with self.assertRaises(ValueError): security.validate_published(records, METADATA, SHA, 12, 2)


class ScannerTests(unittest.TestCase):
    def test_platform_resolution_pins_child_and_validates_architecture(self):
        descriptor = {'digest': DIGEST, 'manifests': [{'digest': CHILD, 'platform': {'os': 'linux', 'architecture': 'amd64'}}]}
        def result(args, obj): return subprocess.CompletedProcess(args, 0, json.dumps(obj), '')
        def run(*args, **kwargs):
            if '--raw' in args: return subprocess.CompletedProcess(args, 0, MANIFEST, '')
            if 'imagetools' in args: return result(args, descriptor)
            if 'inspect' in args: return result(args, [{'Os': 'linux', 'Architecture': 'amd64'}])
            return result(args, {})
        with patch.object(security, 'command', side_effect=run):
            self.assertEqual(security.resolve_image(IMAGE + '@' + DIGEST, 'linux/amd64')['image'], IMAGE + '@' + CHILD)
            with self.assertRaises(ValueError): security.resolve_image(IMAGE + '@' + CHILD, 'linux/amd64')
            with self.assertRaises(ValueError): security.resolve_image(IMAGE + '@' + DIGEST, 'linux/arm64')
            descriptor['digest'] = CHILD
            with self.assertRaises(ValueError): security.resolve_image(IMAGE + '@' + CHILD, 'linux/amd64')

    def test_findings_and_malformed_results_fail_closed(self):
        clean = {'SchemaVersion': 2, 'Metadata': {}, 'Results': []}
        self.assertEqual(security.classify_scan(clean, 0, IMAGE)['status'], 'success')
        report = clean | {'Results': [{'Vulnerabilities': [{'Severity': 'HIGH'}], 'Secrets': [{'Severity': 'CRITICAL'}]}]}
        self.assertEqual(security.classify_scan(report, 0, IMAGE)['status'], 'findings')
        for report, code in [(clean, 1), (clean, 2), ({}, 0), (clean | {'Results': {}}, 0),
                             (clean | {'Results': [{'Secrets': [{'Severity': 'invalid'}]}]}, 0),
                             (clean | {'Results': [{'Vulnerabilities': None}]}, 0)]:
            with self.assertRaises(ValueError): security.classify_scan(report, code, IMAGE)

    def test_secret_never_exempted_by_fixed_vulnerability_disposition(self):
        policy = {'image': IMAGE, 'approved': True, 'expires': (dt.datetime.now(dt.timezone.utc) + dt.timedelta(days=1)).isoformat(),
                  'package': 'tempo', 'installed_version': 'fixed', 'fixed_findings': ['CVE-1']}
        finding = {'VulnerabilityID': 'CVE-1', 'PkgName': 'tempo', 'InstalledVersion': 'fixed', 'Severity': 'HIGH'}
        report = {'SchemaVersion': 2, 'Metadata': {}, 'Results': [{'Vulnerabilities': [finding], 'Secrets': [{'Severity': 'HIGH'}]}]}
        result = security.classify_scan(report, 1, IMAGE, policy)
        self.assertEqual(result['high'], 1)
        self.assertEqual(len(result['fixed_findings']), 1)


class CompleteAttemptTests(unittest.TestCase):
    def test_one_failure_does_not_hide_remaining_images_or_publish_authorization(self):
        for failure in ['finding', 'timeout', 'malformed']:
            with self.subTest(failure=failure), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                (root / 'ci').mkdir()
                (root / 'ci/state-metadata.json').write_text(json.dumps(METADATA))
                (root / 'ci/dependency-version-targets.json').write_text(json.dumps(SETTINGS))
                published = root / 'published'
                published.mkdir()
                (published / 'image.json').write_text(json.dumps({'image': IMAGE, 'digest': DIGEST, 'snapshot': SHA, 'run_id': '12', 'run_attempt': '2'}))
                entries = ENTRIES + [{'key': 'compose/database', 'source': 'postgres:16'}]
                def command(*args, **kwargs):
                    for flag, path in [('--download-db-only', 'db'), ('--download-java-db-only', 'java-db')]:
                        if flag in args:
                            location = root / '.runtime-security-cache' / path
                            location.mkdir(parents=True, exist_ok=True)
                            (location / 'metadata.json').write_text(json.dumps({'UpdatedAt': dt.datetime.now(dt.timezone.utc).isoformat()}))
                    return subprocess.CompletedProcess(args, 0, '', '')
                attempts = []
                def scan(args, **kwargs):
                    if args[:3] == ['docker', 'rm', '-f']:
                        return subprocess.CompletedProcess(args, 0, '', '')
                    attempts.append(args)
                    report = {'SchemaVersion': 2, 'Metadata': {}, 'Results': []}
                    if len(attempts) == 1:
                        if failure == 'timeout': raise subprocess.TimeoutExpired('scanner', 600)
                        if failure == 'malformed': return subprocess.CompletedProcess(args, 0, 'invalid', '')
                        report['Results'] = [{'Vulnerabilities': [{'Severity': 'HIGH'}]}]
                    return subprocess.CompletedProcess(args, 1 if len(attempts) == 1 else 0, json.dumps(report), 'retained diagnostic')
                def resolve(ref, platform):
                    return {'image': security.image_repository(ref) + '@' + CHILD, 'index_image': security.image_repository(ref) + '@' + DIGEST, 'platform': platform}
                env = {'GITHUB_SHA': SHA, 'GITHUB_REPOSITORY': 'finos/traderX', 'GITHUB_RUN_ID': '12', 'GITHUB_RUN_ATTEMPT': '2', 'GITHUB_EVENT_NAME': 'push'}
                output = root / 'runtime-lock.json'
                argv = ['scan', '--root', str(root), '--published', str(published), '--reports', str(root / 'reports'), '--output', str(output)]
                with patch.object(sys, 'argv', argv), patch.dict(security.os.environ, env), \
                     patch.object(security, 'runtime_inventory', return_value=entries), patch.object(security, 'command', side_effect=command), \
                     patch.object(security, 'resolve_image', side_effect=resolve), patch.object(security.subprocess, 'run', side_effect=scan):
                    with self.assertRaises(ValueError): security.main()
                self.assertEqual(len(attempts), 2)
                summary = json.loads((root / 'reports/summary.json').read_text())
                self.assertEqual(summary[1]['status'], 'success')
                self.assertFalse(output.exists())
                self.assertTrue((root / 'reports/1.json').exists())


class HostAuthorizationTests(unittest.TestCase):
    def test_host_requires_exact_coverage_platform_freshness_and_digest_map(self):
        spec = importlib.util.spec_from_file_location('deploy', ROOT / 'pipeline/deploy-verified-snapshot.py')
        deploy = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(deploy)
        lock = lock_fixture(dt.datetime.now(dt.timezone.utc))
        record = {'state': METADATA['stateId'], 'snapshot': SHA, 'repository': 'finos/traderX',
                  'runtime_metadata': METADATA, 'runtime_lock': lock,
                  'checks': {'build-and-publish.yml': {'id': 12, 'attempt': 2}},
                  'runtime_images': {e['key']: e for e in lock['images']}}
        config = {'services': {'ingress': {'image': IMAGE + ':' + SHA, 'build': {'context': '.'}}}}
        with patch.object(deploy, 'run', return_value=subprocess.CompletedProcess([], 0, 'linux/amd64', '')):
            good = copy.deepcopy(config)
            deploy.authorize_runtime(good, record, SETTINGS, None)
            self.assertEqual(good['services']['ingress'], {'image': IMAGE + '@' + CHILD})
            changed = copy.deepcopy(config)
            changed['services']['sidecar'] = {'image': 'alpine:3'}
            with self.assertRaises(ValueError): deploy.authorize_runtime(changed, record, SETTINGS, None)
            with self.assertRaises(ValueError): deploy.authorize_runtime(config, record | {'runtime_images': {}}, SETTINGS, None)
            with self.assertRaises(ValueError): deploy.authorize_runtime(config, record | {'runtime_lock': lock_fixture(NOW - dt.timedelta(days=10))}, SETTINGS, None)
        with patch.object(deploy, 'run', return_value=subprocess.CompletedProcess([], 0, 'linux/arm64', '')):
            with self.assertRaises(ValueError): deploy.authorize_runtime(config, record, SETTINGS, None)

    def test_host_scan_cannot_reresolve_mutable_tag_or_substitute_authorized_digest(self):
        spec = importlib.util.spec_from_file_location('deploy', ROOT / 'pipeline/deploy-verified-snapshot.py')
        deploy = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(deploy)
        authorized = {e['key']: e for e in lock_fixture()['images']}
        config = {'services': {'ingress': {'image': IMAGE + '@' + CHILD}}}
        clean = {'SchemaVersion': 2, 'Metadata': {}, 'Results': []}
        with tempfile.TemporaryDirectory() as tmp, patch.object(deploy, 'run', return_value=subprocess.CompletedProcess([], 0, '', '')) as commands, \
             patch.object(deploy.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, json.dumps(clean), '')) as scanner:
            deploy.scan_infrastructure(config, {}, Path(tmp) / 'reports', authorized=authorized, scanner_image='scanner')
            self.assertFalse(any('inspect' in c.args for c in commands.call_args_list))
            self.assertEqual(scanner.call_args.args[0][-1], IMAGE + '@' + CHILD)
        config['services']['ingress']['image'] = IMAGE + ':latest'
        with tempfile.TemporaryDirectory() as tmp, patch.object(deploy, 'run', return_value=subprocess.CompletedProcess([], 0, '', '')):
            with self.assertRaises(ValueError): deploy.scan_infrastructure(config, {}, Path(tmp) / 'reports', authorized=authorized, scanner_image='scanner')


if __name__ == '__main__': unittest.main()
