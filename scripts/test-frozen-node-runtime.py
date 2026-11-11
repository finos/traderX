#!/usr/bin/env python3
"""Verify generated workflows and application builds consume frozen Node policy."""
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('policy', ROOT / 'pipeline/install-runtime-image-policy.py')
policy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(policy)


class FrozenNodeTests(unittest.TestCase):
    def test_generated_workflows_share_canonical_node_and_frozen_installs(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp)
            for module in ('reference-data', 'fdc3-intent-interoperability/sail/bootstrap/dependency-overlay'):
                directory = target / module
                directory.mkdir(parents=True)
                (directory / 'package.json').write_text('{"name":"fixture","version":"1.0.0"}')
                (directory / 'package-lock.json').write_text('{"lockfileVersion":3}')
            subprocess.run(['bash', str(ROOT / 'pipeline/install-generated-ci-assets.sh'),
                            '002-edge-proxy-uncontainerized', str(target)], check=True, capture_output=True)
            version = policy.load_policy()['npm']['nodeVersion']
            workflows = list((target / '.github/workflows').glob('*.yml'))
            versions = [v for p in workflows for v in re.findall(r"node-version: '([^']+)'", p.read_text())]
            self.assertGreaterEqual(len(versions), 4)  # build, security, license, Sail audit
            self.assertEqual(set(versions), {version})
            for name in ('security.yml', 'license-scanning-node.yml'):
                text = (target / '.github/workflows' / name).read_text()
                self.assertIn('npm ci --omit=dev', text)
                self.assertNotIn('npm install --omit=dev', text)
            self.assertFalse(any('@@NODE_VERSION@@' in p.read_text() for p in workflows))

    def test_application_build_requires_lock_and_preserves_tool_recipes(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp)
            for directory in ('app', 'unlocked', 'runtime-images/sail'):
                path = target / directory
                path.mkdir(parents=True)
                if directory != 'unlocked':
                    (path / 'package-lock.json').write_text('{}')
                (path / 'Dockerfile.compose').write_text('FROM node:24-alpine\nCOPY package.json ./\nRUN npm install --omit=dev && npm cache clean --force\nRUN npm install -g example-tool\n')
            policy.normalize_base_images(target, policy.load_policy())
            app = (target / 'app/Dockerfile.compose').read_text()
            self.assertIn('COPY package.json package-lock.json ./', app)
            self.assertIn('RUN npm ci --omit=dev && npm cache clean --force', app)
            self.assertIn('RUN npm install -g example-tool', app)
            for directory in ('unlocked', 'runtime-images/sail'):
                self.assertIn('RUN npm install --omit=dev', (target / directory / 'Dockerfile.compose').read_text())
            before = (target / 'app/Dockerfile.compose').read_text()
            policy.normalize_base_images(target, policy.load_policy())
            self.assertEqual(before, (target / 'app/Dockerfile.compose').read_text())


if __name__ == '__main__':
    unittest.main()
