import unittest
from unittest.mock import Mock,patch

import bootstrap_database
import credential_store
import database_lifecycle as db
import trading_lifecycle as trading
from verify_trading_lifecycle import settled_trade_id


class TradingLifecycleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.reference=bootstrap_database.pinned_reference()
        cls.credentials={'contract':credential_store.contract(),'bootstrap':{'username':'traderx','password':'b'*64},'runtime':bootstrap_database.credentials()}

    def test_only_reviewed_workloads_and_no_external_services(self):
        docs=trading.resources(self.reference,self.credentials,'traderx-security-lab-test')
        deployments=[d for d in docs if d['kind']=='Deployment']
        self.assertEqual(set(trading.ORDER),{d['metadata']['name'] for d in deployments})
        self.assertTrue(all(d['spec']['replicas']==0 for d in deployments))
        self.assertFalse(any(d['kind']=='Secret' for d in docs))
        for d in docs:
            if d['kind']=='Service':
                self.assertEqual('ClusterIP',d['spec']['type'])
                self.assertTrue(all('nodePort' not in p for p in d['spec']['ports']))

    def test_admission_scoped_to_candidate_namespace(self):
        namespace='traderx-security-lab-test'
        docs=trading.resources(self.reference,self.credentials,namespace)
        policies={d['metadata']['name']:d for d in docs if d['kind']=='ValidatingAdmissionPolicy'}
        for policy in policies.values():
            self.assertTrue(policy['metadata']['name'].endswith('-test'))
            self.assertIn(namespace,policy['spec']['matchConditions'][0]['expression'])
        for d in docs:
            if d['kind']=='ValidatingAdmissionPolicyBinding':self.assertIn(d['spec']['policyName'],policies)

    def test_stop_waits_for_all_owned_pods(self):
        api=Mock(namespace='traderx-security-lab-test')
        api.get.return_value=None
        api.run.return_value='{"items":[{"metadata":{"name":"owned"}}]}'
        with patch.object(db,'stop') as stop:
            trading.stop(api,self.credentials)
            stop.assert_called_once()
        self.assertEqual('wait',api.run.call_args_list[-1].args[0][0])

    def test_original_namespace_cannot_be_used(self):
        api=Mock(namespace=db.NS)
        with patch.object(db,'namespace'):
            with self.assertRaises(ValueError):trading.start(api,self.reference,self.credentials,None)
        api.create.assert_not_called()

    def test_resource_drift_refused_before_create(self):
        api=Mock(namespace='traderx-security-lab-test')
        api.get.return_value={'metadata':{'name':'foreign'}}
        with patch.object(db,'namespace'):
            with self.assertRaises(ValueError):trading.start(api,self.reference,self.credentials,None)
        api.create.assert_not_called()


class TradeCorrelationTests(unittest.TestCase):
    def row(self,**values):
        return dict({'accountId':22214,'security':'IBM','side':'Buy','quantity':4500,'state':'Settled','id':'committed-uuid'},**values)

    def test_committed_id_can_differ_from_null_submission_id(self):
        self.assertEqual('committed-uuid',settled_trade_id([self.row()],4500))

    def test_unrelated_or_pending_trade_does_not_match(self):
        self.assertIsNone(settled_trade_id([self.row(accountId=44044),self.row(state='New')],4500))

    def test_duplicate_effect_is_rejected(self):
        with self.assertRaises(RuntimeError):settled_trade_id([self.row(),self.row(id='another')],4500)

    def test_null_committed_identifier_is_rejected(self):
        with self.assertRaises(RuntimeError):settled_trade_id([self.row(id=None)],4500)
