#!/usr/bin/env python3
"""Check API Explorer creation participates in final runtime image normalization."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('fixture', ROOT / 'scripts/test-runtime-image-policy.py')
fixture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixture)


class ExplorerPolicyTests(unittest.TestCase):
    def test_api_installer_runs_before_policy_without_relaxing_nested_guard(self):
        text = (ROOT / 'pipeline/generate-state.sh').read_text()
        api = text.index('bash "${ROOT}/pipeline/install-generated-api-explorer.sh"')
        policy = text.index('python3 "${ROOT}/pipeline/install-runtime-image-policy.py"')
        ci = text.index('bash "${ROOT}/pipeline/install-generated-ci-assets.sh"')
        self.assertLess(api, policy)
        self.assertLess(policy, ci)
        self.assertIn('if (( GEN_DEPTH == 1 )) || [[ "${TRADERX_INSTALL_API_EXPLORER_IN_NESTED_GENERATION:-0}" == "1" ]]; then', text[:api])
        self.assertIn('if (( GEN_DEPTH == 1 )); then', text[api:policy])

    def test_real_api_kubernetes_installer_gets_pinned_before_packaging(self):
        # Exercise the actual installer function; unrelated HTML/npm vendoring
        # is intentionally outside this image/build-plan regression.
        source = (ROOT / 'pipeline/install-generated-api-explorer.sh').read_text()
        function = 'ensure_kubernetes_explorer() {' + source.split('ensure_kubernetes_explorer() {', 1)[1].split('\ninstall_edge_proxy_explorer\n', 1)[0]
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp)
            fixture.patch_fixture(target, 10)
            explorer = target / 'api-explorer'
            explorer.mkdir()
            tilt = target / 'tilt-kubernetes-dev-loop'
            tilt.mkdir()
            (tilt / 'upstream-build-plan.json').write_text('{}')
            subprocess.run(['bash', '-eu', '-c', function + '\nensure_kubernetes_explorer'], check=True,
                           env=dict(os.environ, TARGET_ROOT=tmp, EXPLORER_ROOT=str(explorer)), capture_output=True)
            self.assertIn('FROM nginx:1.27-alpine', (explorer / 'Dockerfile').read_text())
            fixture.policy_module.install('010-fixture', target)
            expected = fixture.policy_module.load_policy()['docker']['baseImages']['nginx:1.27-alpine']
            self.assertIn('FROM ' + expected, (explorer / 'Dockerfile').read_text())
            plan = json.loads((target / 'kubernetes-runtime/build-plan.json').read_text())
            entry = next(i for i in plan['images'] if i['name'] == 'api-explorer')
            self.assertEqual(entry['context'], 'api-explorer')
            self.assertEqual(entry['image'], 'traderx-api-explorer:local')
            self.assertEqual(json.loads((tilt / 'upstream-build-plan.json').read_text()), plan)


if __name__ == '__main__':
    unittest.main()
