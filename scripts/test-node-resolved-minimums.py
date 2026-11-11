#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import unittest

path = Path(__file__).resolve().parents[1] / 'pipeline/validate-node-resolved-minimums.py'
spec = importlib.util.spec_from_file_location('minimums', path)
minimums = importlib.util.module_from_spec(spec)
spec.loader.exec_module(minimums)


class MinimumTests(unittest.TestCase):
    def test_nested_stale_resolution_is_rejected(self):
        lock = {'packages': {'node_modules/engine.io': {'version': '6.6.11'},
            'node_modules/karma/node_modules/engine.io': {'version': '6.6.10'}}}
        with self.assertRaises(ValueError):
            minimums.validate(lock, {'engine.io': '6.6.11'})

    def test_patched_stable_versions_pass(self):
        for version in ['6.6.11', '6.6.12', '6.7.0']:
            minimums.validate({'packages': {'node_modules/engine.io': {'version': version}}}, {'engine.io': '6.6.11'})

    def test_unverifiable_and_prerelease_versions_fail_closed(self):
        for version in [None, '6.6.11-beta.1', 'latest', 'file:../engine']:
            with self.assertRaises(ValueError):
                minimums.validate({'packages': {'node_modules/engine.io': {'version': version}}}, {'engine.io': '6.6.11'})
        with self.assertRaises(ValueError):
            minimums.validate({}, {'engine.io': '6.6.11'})


if __name__ == '__main__':
    unittest.main()
