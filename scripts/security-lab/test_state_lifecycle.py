import json
import unittest
from unittest.mock import Mock,patch

import bootstrap_database
import control_bundle
import credential_store
import state_lifecycle as state
import telemetry_lifecycle
import trading_lifecycle


class StateLifecycleTests(unittest.TestCase):
    def test_all_twelve_policy_families_are_present(self):
        reference=bootstrap_database.pinned_reference()
        creds={'bootstrap':{'password':'d'*64},'runtime':bootstrap_database.credentials(),'contract':credential_store.contract()}
        docs=state.database_policies(creds,'traderx-security-lab-019')+telemetry_lifecycle.resources(reference,creds,'traderx-security-lab-019')+trading_lifecycle.resources(reference,creds,'traderx-security-lab-019')
        actual={d['metadata']['name'].removesuffix('-019') for d in docs if d['kind']=='ValidatingAdmissionPolicy'}
        expected={d['metadata']['name'] for d in control_bundle.render(reference)[0]['items'] if d['kind']=='ValidatingAdmissionPolicy'}
        self.assertEqual(expected,actual)
        self.assertEqual(12,len(actual))

    def test_readiness_requires_the_collector_as_well_as_all_workloads(self):
        credentials={'bootstrap':{'password':'d'*64}}
        api=Mock(namespace='traderx-security-lab-019')
        owner=state.db.identity(credentials)
        names=set(trading_lifecycle.ORDER+telemetry_lifecycle.ORDER+['database'])
        api.run.return_value=json.dumps({'items':[{'metadata':{'name':n,'labels':{state.db.OWNER:owner}},'status':{'readyReplicas':1}} for n in names]})
        api.get.return_value={'metadata':{'labels':{state.db.OWNER:owner}},'status':{'desiredNumberScheduled':1,'numberReady':0}}
        with self.assertRaises(RuntimeError):state.ready(api,credentials)
        api.get.return_value['status']['numberReady']=1
        state.ready(api,credentials)

    def test_shutdown_continues_if_one_component_fails(self):
        with patch.object(state.telemetry_lifecycle,'stop',side_effect=ValueError('refused')),patch.object(state.trading_lifecycle,'stop') as trading_stop:
            with self.assertRaises(RuntimeError):state.stop(Mock(),{})
            trading_stop.assert_called_once()
