import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import portability
import resource_preflight
import verify_bootstrap


class PortabilityTests(unittest.TestCase):
    def test_docker_selection_is_explicit_and_local(self):
        with patch.dict(os.environ, {}, clear=True), patch('portability.platform.system', return_value='Linux'):
            self.assertIn(str(Path.home()/'.docker/run/docker.sock'), portability.docker(Path('/runtime'))[-1])
            with patch.dict(os.environ, {'TRADERX_LAB_ISOLATED_LINUX': '1'}):
                self.assertEqual(portability.docker(Path('/runtime'))[-1], 'unix:///var/run/docker.sock')
                with patch.dict(os.environ, {'TRADERX_LAB_DOCKER_HOST': 'tcp://example.test:2375'}):
                    with self.assertRaises(ValueError): portability.docker(Path('/runtime'))
            with patch.dict(os.environ, {'TRADERX_LAB_ISOLATED_LINUX': 'yes'}):
                with self.assertRaises(ValueError): portability.docker(Path('/runtime'))
        with patch.dict(os.environ, {'TRADERX_LAB_ISOLATED_LINUX': '1'}, clear=True), patch('portability.platform.system', return_value='Darwin'):
            with self.assertRaises(ValueError): portability.docker(Path('/runtime'))

    def test_java_requires_explicit_executable_on_linux(self):
        with tempfile.TemporaryDirectory() as root, patch.dict(os.environ, {}, clear=True), patch('portability.platform.system', return_value='Linux'):
            with self.assertRaises(ValueError): portability.java()
            java = Path(root)/'bin/java'
            java.parent.mkdir()
            java.write_text('')
            with patch.dict(os.environ, {'JAVA_HOME': root}):
                with self.assertRaises(ValueError): portability.java()
                java.chmod(0o700)
                self.assertEqual(portability.java(), str(java))

    def test_linux_preflight_blocks_other_modes_and_unavailable_observation(self):
        with patch.dict(os.environ, {'TRADERX_LAB_ISOLATED_LINUX': '1'}, clear=True), patch('portability.platform.system', return_value='Linux'):
            with patch('resource_preflight.observe', side_effect=OSError):
                for mode in ('fixture', 'build', 'development', 'acceptance'):
                    self.assertEqual(resource_preflight.check(Path('/unused'), mode)['status'], 'blocked')

    def test_linux_preflight_blocks_running_containers(self):
        def run(args, **kwargs):
            output = '{"Name":"other","MemUsage":"1MiB / 1GiB"}\n' if 'stats' in args else str(8*resource_preflight.GIB)
            return subprocess.CompletedProcess(args, 0, stdout=output)
        with patch.dict(os.environ, {'TRADERX_LAB_ISOLATED_LINUX': '1'}, clear=True), patch('portability.platform.system', return_value='Linux'), patch('resource_preflight.subprocess.run', side_effect=run):
            self.assertEqual(resource_preflight.check(Path('/unused'), 'fixture')['status'], 'blocked')

    def test_linux_preflight_requires_memory_and_low_pressure(self):
        def run(args, **kwargs):
            output = '' if 'stats' in args else str(8*resource_preflight.GIB)
            return subprocess.CompletedProcess(args, 0, stdout=output)
        def read(path):
            if str(path) == '/proc/meminfo':
                return 'MemTotal: 8388608 kB\nMemAvailable: 4194304 kB\n'
            return 'some avg10=1.00 avg60=0.00 avg300=0.00 total=0\n'
        with patch.dict(os.environ, {'TRADERX_LAB_ISOLATED_LINUX': '1'}, clear=True), patch('portability.platform.system', return_value='Linux'), patch('resource_preflight.subprocess.run', side_effect=run), patch.object(Path, 'read_text', read):
            self.assertEqual(resource_preflight.check(Path('/unused'), 'fixture')['status'], 'blocked')
            with patch.object(Path, 'read_text', side_effect=OSError):
                self.assertEqual(resource_preflight.check(Path('/unused'), 'fixture')['status'], 'blocked')

    def test_fixture_cleans_owned_resources_after_create_timeout(self):
        calls = []
        def run(args, **kwargs):
            calls.append(args)
            if 'create' in args and '--name' in args:
                raise subprocess.TimeoutExpired(args, 60)
            if 'volume' in args and 'create' in args:
                return subprocess.CompletedProcess(args, 0, stdout='fixture-volume\n')
            if 'ps' in args:
                return subprocess.CompletedProcess(args, 0, stdout='owned-container\n')
            if 'volume' in args and 'ls' in args:
                return subprocess.CompletedProcess(args, 0, stdout='fixture-volume\n')
            return subprocess.CompletedProcess(args, 0, stdout='')
        with tempfile.TemporaryDirectory() as root, patch('verify_bootstrap.subprocess.run', side_effect=run):
            with self.assertRaises(subprocess.TimeoutExpired):
                with verify_bootstrap.database(Path(root), 'image', persistent=True, loopback=True):
                    pass
        create = next(c for c in calls if '--name' in c)
        self.assertIn('127.0.0.1::5432', create)
        self.assertTrue(any('rm' in c and 'owned-container' in c for c in calls))
        self.assertTrue(any('rm' in c and 'fixture-volume' in c for c in calls))
        for c in (next(c for c in calls if 'ps' in c), next(c for c in calls if 'volume' in c and 'ls' in c)):
            self.assertTrue(any('traderx.security-lab.bootstrap=' in arg for arg in c))


if __name__ == '__main__':
    unittest.main()
