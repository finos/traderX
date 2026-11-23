import subprocess
import unittest
from pathlib import Path
from unittest.mock import patch
from resource_preflight import assess, check, memory_bytes, GIB, LAB


class ResourceTests(unittest.TestCase):
    def snapshot(self, names=(), used=0, pressure='normal'):
        return {'host_pressure': pressure, 'docker_memory_bytes': 6*GIB,
                'containers': [{'name': name, 'memory_bytes': used} for name in names]}

    def test_units_and_bad_observations(self):
        self.assertEqual(memory_bytes('1.5 GiB'), int(1.5*GIB))
        self.assertEqual(memory_bytes('32MiB'), 32*1024**2)
        self.assertEqual(memory_bytes('1GB'), 1000**3)
        for text in ('NaN GiB', '-1 GiB', '100', '1 XB'):
            with self.assertRaises(ValueError): memory_bytes(text)

    def test_fixture_refuses_full_lab_even_with_headroom(self):
        self.assertEqual(assess(self.snapshot([LAB], GIB), 'fixture')['status'], 'blocked')
        self.assertEqual(assess(self.snapshot(), 'fixture')['status'], 'ready')

    def test_acceptance_requires_lab_and_margin(self):
        self.assertEqual(assess(self.snapshot(), 'acceptance')['status'], 'blocked')
        self.assertEqual(assess(self.snapshot([LAB], 5.5*GIB), 'acceptance')['status'], 'blocked')
        self.assertEqual(assess(self.snapshot([LAB], 4*GIB), 'acceptance')['status'], 'ready')

    def test_pressure_and_other_cluster(self):
        for mode in ('development', 'fixture', 'acceptance'):
            for pressure in ('elevated', 'unknown'):
                self.assertEqual(assess(self.snapshot(pressure=pressure), mode)['status'], 'blocked')
        snap = self.snapshot([LAB, 'traderx-state-014-control-plane'], GIB)
        self.assertEqual(assess(snap, 'acceptance')['status'], 'blocked')
        self.assertEqual(assess(self.snapshot([LAB], GIB), 'development')['status'], 'blocked')

    def test_daemon_timeout_fails_closed(self):
        with patch('resource_preflight.observe', side_effect=subprocess.TimeoutExpired('docker', 15)):
            self.assertEqual(check(Path('/unused'), 'fixture')['status'], 'blocked')


if __name__ == '__main__': unittest.main()
