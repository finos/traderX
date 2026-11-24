import unittest
import storage_preflight as disk


class DiskTests(unittest.TestCase):
    def test_space_and_reserve(self):
        fmt='Filesystem 1024-blocks Used Available Capacity Mounted on\n/dev/vda1 60000000 60000000 {} 100% /var\n'
        self.assertEqual(disk.require(fmt.format(3*1024**2)),3*1024**3)
        with self.assertRaises(RuntimeError):disk.require(fmt.format(0))
        with self.assertRaises(RuntimeError):disk.require(fmt.format(1024))

    def test_unknown_or_invalid_observation_refused(self):
        for text in ('','bad','header\n/dev/vda1 100 50 unknown 50% /var','header\n/dev/vda1 100 50 -1 50% /var'):
            with self.subTest(text=text),self.assertRaises(ValueError):disk.require(text)
