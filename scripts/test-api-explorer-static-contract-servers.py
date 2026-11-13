#!/usr/bin/env python3
"""Regression tests for API explorer static contract route prefixes.

Reference Data has no runtime OpenAPI spec, so the explorer serves its static
contract. Without a `servers` entry, Swagger UI "Try it out" calls the edge root
(e.g. /stocks) and receives the web UI's index.html instead of stock data.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
INSTALLER = ROOT / 'pipeline/install-generated-api-explorer.sh'
VALIDATOR = ROOT / 'pipeline/validate-generated-api-explorer-contracts.sh'
STATE_ID = '004-containerized-compose-runtime'
CATALOG = json.loads((ROOT / 'catalog/state-catalog.json').read_text())['apiCatalog']


def catalog_step_source():
    """The installer's real catalog/contract step (the node heredoc that reads state-catalog.json)."""
    text = INSTALLER.read_text()
    for chunk in text.split("node <<'NODE'\n")[1:]:
        body = chunk.split('\nNODE\n', 1)[0]
        if "'state-catalog.json'" in body:
            return body
    raise AssertionError('catalog step not found in install-generated-api-explorer.sh')


def server_blocks(text):
    return [line for line in text.splitlines() if line.rstrip() == 'servers:']


def run_catalog_step(target, root=ROOT):
    explorer = target / 'api-explorer'
    (explorer / 'contracts').mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, ROOT=str(root), STATE_ID=STATE_ID, TARGET_ROOT=str(target),
               EXPLORER_ROOT=str(explorer), PUBSUB_INSPECTOR_ENABLED='0')
    subprocess.run(['node'], input=catalog_step_source(), text=True, env=env, check=True, capture_output=True)
    return explorer


def make_target(tmp, service_ids):
    target = Path(tmp) / 'target-generated'
    for service_id in service_ids:
        (target / service_id).mkdir(parents=True)
    return target


def run_validator(target, components):
    return subprocess.run(['bash', str(VALIDATOR), STATE_ID, str(target), str(components)],
                          text=True, capture_output=True)


class StaticContractServersTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = self._tmp.name
        self.target = make_target(self.tmp, [s['id'] for s in CATALOG['services']])

    def tearDown(self):
        self._tmp.cleanup()

    def test_reference_data_contract_declares_route_prefix(self):
        explorer = run_catalog_step(self.target)
        contract = (explorer / 'contracts/reference-data-openapi.yaml').read_text()
        self.assertEqual(len(server_blocks(contract)), 1, contract)
        self.assertIn('servers:\n- url: /reference-data\n', contract)
        catalog = json.loads((explorer / 'catalog.json').read_text())
        entry = next(s for s in catalog['services'] if s['id'] == 'reference-data')
        self.assertEqual(entry['runtimeBasePath'], '/reference-data')
        self.assertIsNone(entry['runtimeSpecPath'])

    def test_rerunning_installer_does_not_duplicate_servers_block(self):
        explorer = run_catalog_step(self.target)
        first = (explorer / 'contracts/reference-data-openapi.yaml').read_text()
        run_catalog_step(self.target)
        second = (explorer / 'contracts/reference-data-openapi.yaml').read_text()
        self.assertEqual(first, second)
        self.assertEqual(len(server_blocks(second)), 1)

    def test_source_contract_with_servers_is_not_given_a_second_block(self):
        fixture_root = Path(self.tmp) / 'fixture-root'
        contract = fixture_root / 'contracts/static.yaml'
        contract.parent.mkdir(parents=True)
        source = 'openapi: 3.0.0\nservers:\n- url: /already-declared\npaths: {}\n'
        contract.write_text(source)
        (fixture_root / 'catalog').mkdir()
        (fixture_root / 'catalog/state-catalog.json').write_text(json.dumps({'apiCatalog': {
            'mountPath': '/api/docs',
            'services': [{'id': 'static', 'runtimeBasePath': '/static', 'contractPath': 'contracts/static.yaml'}],
        }}))
        target = make_target(self.tmp + '/fixture', [])
        explorer = run_catalog_step(target, root=fixture_root)
        self.assertEqual((explorer / 'contracts/static-openapi.yaml').read_text(), source)

    def test_contracts_for_services_with_runtime_specs_are_unchanged(self):
        explorer = run_catalog_step(self.target)
        runtime = [s for s in CATALOG['services'] if s.get('runtimeSpecPath') and s.get('contractPath')]
        self.assertTrue(runtime, 'expected catalog services with runtime specs')
        for service in runtime:
            with self.subTest(service=service['id']):
                copied = (explorer / f"contracts/{service['id']}-openapi.yaml").read_bytes()
                self.assertEqual(copied, (ROOT / service['contractPath']).read_bytes())

    def test_final_check_covers_every_served_explorer_copy(self):
        explorer = run_catalog_step(self.target)
        components = Path(self.tmp) / 'components'
        served = {
            'Compose ingress': self.target / 'ingress/api-explorer',
            'edge proxy component': components / 'edge-proxy-specfirst/api-explorer',
        }
        (self.target / 'kubernetes-runtime').mkdir()
        for copy in served.values():
            shutil.copytree(explorer, copy)

        result = run_validator(self.target, components)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('3 served copies', result.stdout)

        # A later overlay restoring the raw upstream contract must be caught, per copy.
        raw = (ROOT / 'specs/001-baseline-uncontainerized-parity/contracts/reference-data/openapi.yaml').read_text()
        for label, copy in {**served, 'api-explorer (Kubernetes image source)': explorer}.items():
            with self.subTest(copy=label):
                contract = copy / 'contracts/reference-data-openapi.yaml'
                good = contract.read_text()
                contract.write_text(raw)
                result = run_validator(self.target, components)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(f'{label}: reference-data contract must declare exactly one servers block', result.stderr)
                contract.write_text(good.replace('paths:', 'servers:\n- url: /reference-data\npaths:', 1))
                self.assertNotEqual(run_validator(self.target, components).returncode, 0)
                contract.write_text(good)

    def test_final_check_rejects_catalog_without_reference_data_prefix(self):
        explorer = run_catalog_step(self.target)
        catalog_file = explorer / 'catalog.json'
        catalog = json.loads(catalog_file.read_text())
        for entry in catalog['services']:
            if entry['id'] == 'reference-data':
                entry['runtimeBasePath'] = None
        catalog_file.write_text(json.dumps(catalog))
        result = run_validator(self.target, Path(self.tmp) / 'components')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('reference-data runtimeBasePath is null, expected /reference-data', result.stderr)


if __name__ == '__main__':
    unittest.main()
