#!/usr/bin/env python3
"""Exercise browser asset pinning and integrity rejection before extraction."""
import base64
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / 'pipeline/install-generated-api-explorer.sh').read_text()
FUNCTION = 'install_nats_ws_vendor() {' + SOURCE.split('install_nats_ws_vendor() {', 1)[1].split('\nif (( PUBSUB_INSPECTOR_ENABLED', 1)[0]


class BrowserAssetTests(unittest.TestCase):
    def exercise(self, disposition):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            archive = root / 'fixture.tgz'
            with tarfile.open(archive, 'w:gz') as tar:
                for name, content in [('esm/nats.js', b'export const fixture = true;'), ('LICENSE', b'Apache-2.0')]:
                    item = tarfile.TarInfo('package/' + name)
                    item.size = len(content)
                    tar.addfile(item, io.BytesIO(content))
            integrity = 'sha512-' + base64.b64encode(hashlib.sha512(archive.read_bytes()).digest()).decode()
            policy = {'npm': {'browserAssets': {'nats.ws': {'version': '1.30.3', 'integrity': integrity}}}}
            if disposition == 'missing':
                policy['npm']['browserAssets'] = {}
            elif disposition == 'mismatch':
                policy['npm']['browserAssets']['nats.ws']['integrity'] = 'sha512-' + base64.b64encode(b'0' * 64).decode()
            policy_path = root / 'policy.json'
            policy_path.write_text(json.dumps(policy))
            binary = root / 'bin'
            binary.mkdir()
            npm = binary / 'npm'
            npm.write_text('#!/bin/sh\nset -eu\n[ "$*" = "pack nats.ws@1.30.3 --ignore-scripts --silent" ]\ntouch "$NPM_MARKER"\ncp "$NPM_FIXTURE" package.tgz\necho package.tgz\n')
            npm.chmod(0o755)
            explorer = root / 'api-explorer'
            explorer.mkdir()
            result = subprocess.run(['bash', '-eu', '-c', FUNCTION + '\ninstall_nats_ws_vendor'],
                                    env=dict(os.environ, ROOT=str(ROOT), EXPLORER_ROOT=str(explorer),
                                             TRADERX_DEPENDENCY_TARGETS_FILE=str(policy_path),
                                             PATH=str(binary) + os.pathsep + os.environ['PATH'],
                                             NPM_MARKER=str(root / 'npm-called'), NPM_FIXTURE=str(archive)),
                                    capture_output=True, text=True)
            vendor = explorer / 'vendor/nats.ws'
            if disposition == 'valid':
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual((vendor / 'nats.js').read_bytes(), b'export const fixture = true;')
                self.assertEqual((vendor / 'LICENSE-nats.ws').read_bytes(), b'Apache-2.0')
            else:
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse((vendor / 'nats.js').exists())
                if disposition == 'missing':
                    self.assertFalse((root / 'npm-called').exists())
                else:
                    self.assertIn('integrity mismatch', result.stderr)

    def test_valid_asset_preserves_bundle_and_license(self):
        self.exercise('valid')

    def test_mismatch_rejects_before_extracting(self):
        self.exercise('mismatch')

    def test_missing_policy_rejects_before_fetching(self):
        self.exercise('missing')


if __name__ == '__main__':
    unittest.main()
