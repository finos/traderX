#!/usr/bin/env python3
"""Apply the actual state006 Compose delta and validate its runtime schema."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def block(number, path):
    patch = next((ROOT / 'specs').glob(f'{number:03d}-*/generation/patches/0001-state-overlay.patch')).read_text()
    return next('diff --git ' + part for part in patch.split('diff --git ')[1:] if part.startswith('a/' + path + ' '))


class ComposePatchTests(unittest.TestCase):
    def test_actual_state006_patch_has_valid_volume_and_preserves_service_restarts(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp)
            subprocess.run(['git', 'init', '-q', tmp], check=True)
            for number in (4, 6):
                patch = block(number, 'containerized-compose/docker-compose.yml')
                subprocess.run(['git', 'apply', '--whitespace=nowarn', '-'], input=patch, text=True, cwd=target, check=True)
            compose = target / 'messaging-nats-replacement/docker-compose.yml'
            result = subprocess.run(['docker', 'compose', '-f', str(compose), 'config', '--format', 'json'],
                                    check=True, capture_output=True, text=True)
            config = json.loads(result.stdout)
            self.assertIn('postgres_state_009_data', config['volumes'])
            self.assertNotIn('restart', config['volumes']['postgres_state_009_data'])
            for name, service in config['services'].items():
                self.assertEqual(service['restart'], 'unless-stopped', name)


if __name__ == '__main__':
    unittest.main()
