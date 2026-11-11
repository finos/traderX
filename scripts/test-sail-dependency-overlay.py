#!/usr/bin/env python3
"""Validate the frozen Sail graph and fail-closed source commit guard."""
import json
import importlib.util
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
OVERLAY = ROOT / 'specs/014-fdc3-intent-interoperability/generation/sail-dependencies'
POLICY = json.loads((ROOT / 'catalog/dependency-version-targets.json').read_text())['npm']['sail']

class SailOverlayTests(unittest.TestCase):
    def test_frozen_graph_matches_manifests_and_web_only_scope(self):
        lock = json.loads((OVERLAY / 'package-lock.json').read_text())['packages']
        for file in POLICY['files']:
            if file == 'package-lock.json':
                continue
            manifest = json.loads((OVERLAY / file).read_text())
            key = '' if file == 'package.json' else str(Path(file).parent)
            for field in ('dependencies', 'devDependencies', 'workspaces'):
                self.assertEqual(manifest.get(field), lock[key].get(field), (file, field))
        self.assertNotIn('packages/electron', lock['']['workspaces'])
        self.assertNotIn('node_modules/electron', lock)
        self.assertEqual(lock['packages/web']['devDependencies']['pm2'], POLICY['dependencies']['pm2'])

    def test_generation_preserves_frozen_graph_and_rejects_drift(self):
        spec = importlib.util.spec_from_file_location('sail_validator', ROOT / 'pipeline/validate-generated-sail-dependencies.py')
        validator = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(validator)
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp)
            overlay = target / validator.RELATIVE
            shutil.copytree(OVERLAY, overlay)
            (overlay / 'policy.json').write_text(json.dumps(POLICY))
            targets = ROOT / 'catalog/dependency-version-targets.json'
            self.assertTrue(validator.validate(target, targets))
            subprocess.run(['bash', str(ROOT / 'pipeline/sync-node-dependency-overrides.sh'), str(target)], check=True, capture_output=True)
            subprocess.run(['bash', str(ROOT / 'pipeline/refresh-generated-node-lockfiles.sh'), str(target)], check=True, capture_output=True)
            self.assertTrue(validator.validate(target, targets))
            manifest = overlay / 'package.json'
            manifest.write_text(manifest.read_text() + '\n')
            with self.assertRaisesRegex(ValueError, 'overlay changed'):
                validator.validate(target, targets)
            shutil.copyfile(OVERLAY / 'package.json', manifest)
            (overlay / 'policy.json').write_text(json.dumps(dict(POLICY, sourceCommit='f' * 40)))
            with self.assertRaisesRegex(ValueError, 'policy differs'):
                validator.validate(target, targets)

    def test_wrong_source_commit_is_rejected_before_copy(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / 'repo'
            target.mkdir()
            subprocess.run(['git', 'init', '-q', str(target)], check=True)
            subprocess.run(['git', '-C', str(target), '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '-qm', 'fixture', '--allow-empty'], check=True)
            script = Path(tmp) / 'apply.cjs'
            shutil.copyfile(OVERLAY / 'apply.cjs', script)
            (Path(tmp) / 'policy.json').write_text(json.dumps(POLICY))
            result = subprocess.run(['node', str(script), str(target)], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Sail dependency overlay requires', result.stderr)
            self.assertFalse((target / 'package.json').exists())

if __name__ == '__main__':
    unittest.main()
