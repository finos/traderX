import unittest
from unittest.mock import patch
from types import SimpleNamespace
import storage_preflight as disk


class DiskTests(unittest.TestCase):
    def observation(self,total,used,available):
        return f'Filesystem 1024-blocks Used Available Capacity Mounted on\n/dev/vda1 {total} {used} {available} 95% /var\n'

    def test_space_and_reserve(self):
        self.assertEqual(disk.require(self.observation(60000000,40000000,3*1024**2)),3*1024**3)
        for available in (0,1024):
            with self.assertRaises(RuntimeError):disk.require(self.observation(60000000,40000000,available))

    def test_real_failure_has_gib_free_but_loki_throttles(self):
        output=self.observation(61202244,55374036,2686884)
        self.assertGreater(disk.available_bytes(output),disk.RESERVE_BYTES)
        self.assertFalse(disk.checks(disk.observe(output))['node_disk_usage_margin'])
        with self.assertRaisesRegex(RuntimeError,'Loki'):disk.require(output)

    def test_usage_margin_boundary_and_reserved_blocks(self):
        for used in (85000000,90000000):
            with self.assertRaises(RuntimeError):disk.require(self.observation(100000000,used,5000000))
        disk.require(self.observation(100000000,84999999,5000000))

    def test_unknown_or_invalid_observation_refused(self):
        for text in ('','bad','header\n/dev/vda1 100 50 unknown 50% /var','header\n/dev/vda1 100 50 -1 50% /var',self.observation(0,0,0),self.observation(100,90,20)):
            with self.subTest(text=text),self.assertRaises(ValueError):disk.require(text)

    def test_node_read_is_scoped_and_readonly(self):
        with patch.object(disk,'selected',return_value='traderx-security-lab-validation'),patch.object(disk.subprocess,'run',return_value=SimpleNamespace(stdout=self.observation(100000000,50000000,45000000))) as run:
            disk.require_node('/private/runtime')
        self.assertEqual(run.call_args.args[0][-5:],['exec','traderx-security-lab-validation-control-plane','df','-Pk','/var/lib/containerd'])
