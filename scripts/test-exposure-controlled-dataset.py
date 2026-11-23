#!/usr/bin/env python3
"""Verify that scaling unrelated portfolios preserves the measured workload."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('controlled', Path(__file__).with_name('exposure-controlled-dataset.py'))
controlled = importlib.util.module_from_spec(spec)
spec.loader.exec_module(controlled)


class ControlledDatasetTest(unittest.TestCase):
    def test_growth_preserves_queries_and_existing_positions(self):
        base = controlled.generate_controlled(1000)
        larger = controlled.generate_controlled(2000)
        for account in (70000, 70020):
            self.assertEqual(controlled.query_fixture(base, account),
                             controlled.query_fixture(larger, account))
        self.assertEqual(larger['positions'][:len(base['positions'])], base['positions'])
        self.assertEqual(len(larger['positions']) - len(base['positions']), 30000)
        self.assertEqual(len({row[0] for row in larger['nodes'] if row[2] == 'account'}), 2000)
        ids = [row[0] for row in larger['nodes']]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertTrue(all(len(security) <= 15 for _, security, _ in larger['positions']))

    def test_seed_is_deterministic(self):
        self.assertEqual(controlled.generate_controlled(1001), controlled.generate_controlled(1001))

    def test_smaller_than_fixed_control_is_rejected(self):
        with self.assertRaises(ValueError):
            controlled.generate_controlled(999)


if __name__ == '__main__':
    unittest.main(verbosity=2)
