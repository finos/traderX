import copy
import unittest
from unittest.mock import patch

import lab


class NetworkTests(unittest.TestCase):
    def setUp(self):
        self.contract = lab.read_json(lab.PROFILE / 'system/flows.json')

    def test_deterministic_and_default_deny(self):
        output = lab.render_network(self.contract)
        self.assertEqual(output, lab.render_network(self.contract))
        self.assertEqual(output['items'][0]['spec'],
            {'podSelector': {}, 'policyTypes': ['Ingress', 'Egress']})
        for item in output['items']:
            self.assertEqual(item['metadata']['namespace'], 'traderx-security-lab')

    def test_each_flow_has_two_scoped_sides(self):
        items = {i['metadata']['name']: i['spec'] for i in lab.render_network(self.contract)['items']}
        for flow in self.contract['flows']:
            src, dst, port = flow['from'], flow['to'], flow['port']
            outgoing = items[f'{src}-to-{dst}-{port}']
            incoming = items[f'{dst}-from-{src}-{port}']
            self.assertEqual(outgoing['egress'], [{'to': [{'podSelector': {'matchLabels': {'app': dst}}}],
                'ports': [{'protocol': 'TCP', 'port': port}]}])
            self.assertEqual(incoming['ingress'], [{'from': [{'podSelector': {'matchLabels': {'app': src}}}],
                'ports': [{'protocol': 'TCP', 'port': port}]}])

    def test_no_unrestricted_egress_or_operator_routes(self):
        for flow in self.contract['flows']:
            self.assertNotIn(flow['to'], ['grafana', 'prometheus', 'api-explorer'])
        for item in lab.render_network(self.contract)['items']:
            for rule in item['spec'].get('egress', []):
                self.assertTrue(rule['to'])
                self.assertTrue(rule['ports'])
                self.assertNotIn('ipBlock', rule['to'][0])

    def test_unknown_workload_port_duplicate_and_namespace_rejected(self):
        for field, value in [('from', 'unknown'), ('to', 'unknown'), ('port', 65530)]:
            changed = copy.deepcopy(self.contract)
            changed['flows'][0][field] = value
            with self.assertRaises(ValueError):
                lab.render_network(changed)
        self.contract['flows'].append(self.contract['flows'][0])
        with self.assertRaises(ValueError):
            lab.render_network(self.contract)
        self.contract['namespace'] = 'traderx'
        with self.assertRaises(ValueError):
            lab.render_network(self.contract)


class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.scenarios = lab.read_json(lab.PROFILE / 'contracts/scenarios.json')
        self.result = dict(scenario_id='database-business-canary', run_id='unit-test-only',
            generated_commit='a' * 40, configuration_sha256='b' * 64,
            profile='hardened-enforcement', collector_ref='fixture://collector',
            before_ref='fixture://before', after_ref='fixture://after',
            application_receipt_ref='fixture://receipt', decision_ref='fixture://decision',
            intervening_layer='runtime', positive_control_passed=True, attempt_executed=True,
            asynchronous_settled=True, normal_workflow_passed=True, effect_observed=False,
            alert_observed=True, containment_observed=False, outcome='prevented')

    def test_consistent_prevention(self):
        self.assertEqual(lab.validate_evidence(self.result, self.scenarios), [])

    def test_alert_or_kill_with_impact_cannot_claim_prevention(self):
        self.result.update(effect_observed=True, containment_observed=True)
        self.assertTrue(lab.validate_evidence(self.result, self.scenarios))
        self.result['outcome'] = 'detected'
        self.assertEqual(lab.validate_evidence(self.result, self.scenarios), [])

    def test_missing_positive_control_or_settlement_is_not_prevention(self):
        for field in ['positive_control_passed', 'attempt_executed', 'asynchronous_settled', 'normal_workflow_passed']:
            changed = dict(self.result, **{field: False})
            self.assertTrue(lab.validate_evidence(changed, self.scenarios))

    def test_unknown_wrong_layer_missing_evidence_and_string_boolean(self):
        for field, value in [('scenario_id', 'unknown'), ('intervening_layer', 'waf'),
                             ('after_ref', ''), ('decision_ref', ''), ('effect_observed', 'false'),
                             ('generated_commit', 'main'), ('configuration_sha256', 'latest')]:
            self.assertTrue(lab.validate_evidence(dict(self.result, **{field: value}), self.scenarios))

    def test_inconclusive_does_not_require_positive_control(self):
        self.result.update(outcome='inconclusive', positive_control_passed=False)
        self.assertEqual(lab.validate_evidence(self.result, self.scenarios), [])


class PinTests(unittest.TestCase):
    def test_ref_name_is_not_a_pin(self):
        with self.assertRaises(ValueError):
            lab.object_text('main', 'README.md')

    def test_mismatched_source_fails_before_inventory(self):
        with patch.object(lab, 'object_text', return_value='Source Commit: `wrong`'):
            with self.assertRaises(ValueError):
                lab.inventory({'generated_commit': 'a' * 40, 'canonical_source_commit': 'b' * 40})


if __name__ == '__main__':
    unittest.main()
