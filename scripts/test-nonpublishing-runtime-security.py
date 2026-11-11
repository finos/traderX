#!/usr/bin/env python3
import copy
import datetime as dt
import json
import os
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'pipeline'))
import nonpublishing_runtime_security as gate

ID = 'sha256:' + 'a' * 64
IDENTITY = {'snapshot': 'b' * 40, 'repository': 'finos/traderX', 'run_id': '12', 'run_attempt': '3',
            'state': '014-fdc3-intent-interoperability', 'event': 'push'}
POLICY = {'runtimeImageScanner': {'image': 'scanner@' + ID, 'version': 'test'},
          'supportedPlatforms': ['linux/amd64'], 'maxEvidenceAgeHours': 24,
          'maxDatabaseAgeHours': 24, 'maxJavaDatabaseAgeHours': 96,
          'kubernetesManifestRenderer': {'version': 'v1.37.2'},
          'kubernetesManifestParser': {'version': '6.0.3'}}
MODULE = {'imageName': 'sail', 'directory': 'sail/runtime-images/sail', 'dockerfile': 'Dockerfile.compose'}
METADATA = {'stateId': IDENTITY['state'], 'isConvergence': False, 'modules': {'docker': [MODULE]},
            'runtime': {'kind': 'compose', 'path': 'sail/compose.yml'}}


def fixture():
    stamp = dt.datetime.now(dt.timezone.utc).isoformat()
    return dict(IDENTITY, module=MODULE, image_id=ID, platform='linux/amd64',
                scanner=POLICY['runtimeImageScanner'], status='success', high=0, critical=0,
                fixed_findings=[], scanned_at=stamp,
                databases={n: {'UpdatedAt': stamp, 'metadata_sha256': ID} for n in ['java', 'vulnerability']})


def raw():
    return {'SchemaVersion': 2, 'Metadata': {'ImageID': ID, 'ImageConfig': {'os': 'linux', 'architecture': 'amd64'}}, 'Results': []}


class LocalEvidence(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.store()

    def tearDown(self):
        self.tmp.cleanup()

    def store(self, record=None, report=None):
        gate.write(self.root / 'local-image.json', record or fixture())
        gate.write(self.root / 'scan.json', report or raw())

    def validate(self):
        return gate.validate_modules(self.root, METADATA, IDENTITY, POLICY)

    def test_complete_exact_run_passes(self):
        self.assertEqual(self.validate()['sail']['image_id'], ID)

    def test_missing_duplicate_wrong_run_module_platform_scanner_fail(self):
        for change in [{'run_attempt': '2'}, {'snapshot': 'c' * 40}, {'repository': 'other/repo'},
                       {'platform': 'linux/arm64'}, {'module': MODULE | {'dockerfile': 'different'}},
                       {'scanner': {}}, {'status': 'skipped'}, {'image_id': 'local:tag'}]:
            self.store(fixture() | change)
            with self.subTest(change=change), self.assertRaises(ValueError): self.validate()
        self.store()
        duplicate = self.root / 'duplicate';duplicate.mkdir()
        gate.write(duplicate / 'local-image.json', fixture())
        with self.assertRaises(ValueError): self.validate()
        (duplicate / 'local-image.json').unlink();(self.root / 'local-image.json').unlink()
        with self.assertRaises(ValueError): self.validate()

    def test_raw_findings_and_forged_configuration_identity_block(self):
        for report in [raw() | {'Metadata': {'ImageID': 'sha256:' + 'd' * 64}},
                       raw() | {'Results': [{'Vulnerabilities': [{'Severity': 'HIGH'}]}]},
                       raw() | {'Results': [{'Secrets': [{'Severity': 'CRITICAL'}]}]}, {}]:
            self.store(report=report if report else {'invalid': True})
            with self.subTest(report=report), self.assertRaises(ValueError): self.validate()

    def test_stale_or_missing_database_and_evidence_fail(self):
        for name, hours in [('java', 97), ('vulnerability', 25)]:
            record = fixture();record['databases'][name]['UpdatedAt'] = (dt.datetime.now(dt.timezone.utc) - dt.timedelta(hours=hours)).isoformat()
            self.store(record)
            with self.assertRaises(ValueError):self.validate()
        record = fixture();record['databases']['java']['UpdatedAt'] = (dt.datetime.now(dt.timezone.utc) - dt.timedelta(hours=72)).isoformat()
        self.store(record);self.validate()
        for change in [{'databases': {}}, {'scanned_at': '2000-01-01T00:00:00Z'}]:
            self.store(fixture() | change)
            with self.assertRaises(ValueError):self.validate()

    def test_compose_build_uses_exact_scanned_context_and_covers_pulled_service(self):
        config = {'services': {'sail': {'image': 'traderx-remediation/sail:014', 'build': {
            'context': str(self.root / MODULE['directory']), 'dockerfile': MODULE['dockerfile']}},
            'infra': {'image': 'postgres:16@' + ID}}}
        with patch.object(gate, 'command', return_value=SimpleNamespace(stdout=json.dumps(config))):
            entries = gate.inventory(self.root, METADATA, self.validate())
        self.assertEqual(len(entries), 2)
        self.assertTrue(any(e['source'] == 'local-build/sail@' + ID for e in entries))
        self.assertTrue(any(e['source'] == 'postgres:16@' + ID for e in entries))
        for change in [{'context': str(self.root / 'unscanned')}, {'args': {'EXTRA': '1'}}, {'dockerfile': 'different'}]:
            bad = copy.deepcopy(config);bad['services']['sail']['build'].update(change)
            with patch.object(gate, 'command', return_value=SimpleNamespace(stdout=json.dumps(bad))):
                with self.assertRaises(ValueError):gate.inventory(self.root, METADATA, self.validate())

    def test_unmapped_local_alias_missing_image_profiles_and_escape_fail(self):
        for service in [{'image': 'traderx-remediation/sail:014'}, {'image': 'local-build/sail@' + ID}, {'image': 'alpine:3', 'platform': 'linux/arm64'}, {}, {'image': 'alpine:3', 'profiles': ['debug']},
                        {'build': {'context': '/outside', 'dockerfile': 'Dockerfile'}}]:
            with patch.object(gate, 'command', return_value=SimpleNamespace(stdout=json.dumps({'services': {'bad': service}}))):
                with self.subTest(service=service), self.assertRaises(ValueError):gate.inventory(self.root, METADATA, self.validate())

    def test_kubernetes_init_sidecar_and_companion_are_complete(self):
        runtime = {'kind': 'kubernetes', 'path': 'kube', 'buildPlan': 'plan.json', 'companions': [METADATA['runtime']]}
        metadata = METADATA | {'runtime': runtime}
        (self.root / 'ci').mkdir()
        gate.write(self.root / 'ci/dependency-version-targets.json', {'security': POLICY})
        gate.write(self.root / 'plan.json', {'images': [{'name': 'sail', 'image': 'traderx/sail:local',
            'context': MODULE['directory'], 'dockerfile': MODULE['dockerfile']}]})
        doc = {'kind': 'Pod', 'metadata': {'name': 'app'}, 'spec': {'containers': [
            {'name': 'app', 'image': 'traderx/sail:local'}, {'name': 'sidecar', 'image': 'alpine:3'}],
            'initContainers': [{'name': 'init', 'image': 'postgres:16'}]}}
        results = [SimpleNamespace(stdout=json.dumps({'clientVersion': {'gitVersion': 'v1.37.2'}})),
                   SimpleNamespace(stdout=json.dumps(doc)),
                   SimpleNamespace(stdout=json.dumps({'services': {'infra': {'image': 'nats:2'}}}))]
        fake_yaml = SimpleNamespace(__version__='6.0.3', safe_load_all=lambda data: [json.loads(data)])
        with patch.dict(sys.modules, {'yaml': fake_yaml}), patch.object(gate, 'command', side_effect=results):
            entries = gate.inventory(self.root, metadata, self.validate())
        self.assertEqual(len(entries), 4)
        self.assertTrue(any('initContainers/init' in e['key'] for e in entries))
        self.assertTrue(any(e['key'] == 'companion/0/compose/infra' for e in entries))

    def test_inventory_job_retains_all_failures_and_never_writes_authorization(self):
        (self.root / 'ci').mkdir()
        gate.write(self.root / 'ci/state-metadata.json', METADATA)
        gate.write(self.root / 'ci/dependency-version-targets.json', {'security': POLICY})
        gate.write(self.root / 'ci/state-009-grafana-fixed-findings.json', {})
        entries = [{'key': 'compose/bad', 'source': 'bad:1'}, {'key': 'compose/good', 'source': 'good:1'}]
        reports = self.root / 'reports'
        previous = Path.cwd()
        try:
            os.chdir(self.root)
            with patch.object(sys, 'argv', ['gate', '--artifacts', str(self.root), '--reports', str(reports)]), \
                 patch.object(gate, 'identity', return_value=IDENTITY), \
                 patch.object(gate, 'command', return_value=SimpleNamespace(stdout=IDENTITY['snapshot'])), \
                 patch.object(gate, 'validate_modules', return_value={'sail': fixture()}), \
                 patch.object(gate, 'inventory', return_value=entries), \
                 patch.object(gate, 'databases', return_value=([], {})), \
                 patch.object(gate, 'resolve_image', return_value={'image': 'repo@' + ID, 'index_image': 'repo@' + ID}), \
                 patch.object(gate, 'scan', side_effect=[ValueError('failed scanner'), ({'status': 'success', 'high': 0, 'critical': 0}, {})]):
                with self.assertRaises(ValueError): gate.main()
            self.assertEqual([r['status'] for r in gate.read(reports / 'summary.json')], ['error', 'success'])
            self.assertFalse((self.root / 'runtime-lock.json').exists())
            self.assertFalse((reports / 'build-only-result.json').exists())
            self.assertFalse(gate.read(reports / 'failure.json')['deployment_authorization'])
        finally:
            os.chdir(previous)

    def test_missing_companion_cannot_be_skipped(self):
        metadata = METADATA | {'runtime': METADATA['runtime'] | {'companions': [METADATA['runtime']]}}
        with patch.object(gate, 'command', side_effect=[SimpleNamespace(stdout=json.dumps({'services': {'infra': {'image': 'nats:2'}}})), ValueError('missing companion')]):
            with self.assertRaises(ValueError):gate.inventory(self.root, metadata, self.validate())


if __name__ == '__main__':
    unittest.main()
