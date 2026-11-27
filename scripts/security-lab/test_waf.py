import copy
import json
import unittest

from verify_waf import envoy_config


class WafComparisonTests(unittest.TestCase):
    def test_only_engine_mode_changes(self):
        configurations = []
        for mode in ['Off', 'DetectionOnly', 'On']:
            config = copy.deepcopy(envoy_config(mode))
            manager = config['static_resources']['listeners'][0]['filter_chains'][0]['filters'][0]['typed_config']
            value = manager['http_filters'][0]['typed_config']['config']['configuration']
            directives = json.loads(value['value'])
            self.assertIn('SecRuleEngine ' + mode, directives['directives_map']['default'])
            directives['directives_map']['default'].remove('SecRuleEngine ' + mode)
            value['value'] = json.dumps(directives)
            configurations.append(config)
        self.assertEqual(configurations[0], configurations[1])
        self.assertEqual(configurations[1], configurations[2])

    def test_unknown_mode_rejected(self):
        with self.assertRaises(ValueError):
            envoy_config('on')
