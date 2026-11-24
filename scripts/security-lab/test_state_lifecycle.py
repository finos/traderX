from contextlib import nullcontext
from types import SimpleNamespace
from pathlib import Path
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

    def test_disk_guard_blocks_start_and_test_before_workload_changes(self):
        for action in ('start','test'):
            args=SimpleNamespace(action=action,output=Path('/unused/evidence.json'),store=Path('/private/store'),runtime_dir=Path('/runtime'),kubeconfig=Path('/private/kube'),context='reviewed',cluster_uid='uid',namespace='traderx-security-lab-019')
            with self.subTest(action=action),patch.object(state.argparse.ArgumentParser,'parse_args',return_value=args),patch.object(state.credential_store,'load',return_value={}),patch.object(state.db,'Kubernetes'),patch.object(state,'operation',return_value=nullcontext()),patch.object(state.storage_preflight,'require_node',side_effect=RuntimeError('disk blocked')),patch.object(state.bootstrap_database,'pinned_reference') as reference,patch.object(state,'start') as start,patch.object(state,'ready') as ready,patch.object(state,'stop') as stop:
                with self.assertRaisesRegex(RuntimeError,'disk blocked'):state.main()
                reference.assert_not_called();start.assert_not_called();ready.assert_not_called();stop.assert_not_called()
