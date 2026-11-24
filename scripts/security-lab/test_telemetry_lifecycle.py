import copy
import unittest
from unittest.mock import Mock,patch

import bootstrap_database
import credential_store
import database_lifecycle as db
import telemetry_lifecycle as telemetry


class TelemetryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.reference=bootstrap_database.pinned_reference()
        cls.credentials={'contract':credential_store.contract(),'bootstrap':{'username':'traderx','password':'c'*64},'runtime':bootstrap_database.credentials()}
        cls.namespace='traderx-security-lab-019'

    def test_isolated_collector_namespace_rbac_and_sink(self):
        docs=telemetry.resources(self.reference,self.credentials,self.namespace)
        infra='traderx-security-infra-019'
        cm=next(d for d in docs if d['kind']=='ConfigMap' and d['metadata']['namespace']==infra)
        self.assertIn('metadata.namespace='+self.namespace,cm['data']['vector.toml'])
        self.assertIn('http://loki.'+self.namespace+'.svc.cluster.local',cm['data']['vector.toml'])
        role=next(d for d in docs if d['kind']=='ClusterRole')
        self.assertEqual(['get','list','watch'],role['rules'][0]['verbs'])
        self.assertNotIn('secrets',role['rules'][0]['resources'])
        binding=next(d for d in docs if d['kind']=='ClusterRoleBinding')
        self.assertEqual(infra,binding['subjects'][0]['namespace'])
        self.assertEqual(role['metadata']['name'],binding['roleRef']['name'])

    def test_initial_resources_are_stopped_and_scoped(self):
        docs=telemetry.resources(self.reference,self.credentials,self.namespace)
        for d in docs:
            if d['kind']=='Deployment':self.assertEqual(0,d['spec']['replicas'])
            if d['kind']=='DaemonSet':self.assertIn(telemetry.DISABLED,d['spec']['template']['spec']['nodeSelector'])
            if d['kind']=='ValidatingAdmissionPolicy':
                self.assertTrue(d['metadata']['name'].endswith('-019'))
                self.assertIn('-019',d['spec']['matchConditions'][0]['expression'])

    def test_initializer_nonroot_bounded_no_token_and_no_reset(self):
        job=telemetry.storage_job(self.reference,self.credentials,self.namespace,'loki')
        spec=job['spec']['template']['spec'];container=spec['containers'][0]
        self.assertEqual(10001,spec['securityContext']['runAsUser'])
        self.assertFalse(spec['automountServiceAccountToken'])
        self.assertEqual('lab-telemetry-init',spec['serviceAccountName'])
        self.assertIn('@sha256:',container['image'])
        command=container['command'][-1]
        self.assertNotIn('rm ',command)
        self.assertIn('ls -A /store',command)
        self.assertIn('/store/tmp/loki /store/loki',command)
        self.assertIn('set -C',command)
        self.assertEqual(0,job['spec']['backoffLimit'])
        with self.assertRaises(ValueError):telemetry.storage_job(self.reference,self.credentials,self.namespace,'unreviewed')

    def test_foreign_namespace_refused_before_creation(self):
        api=Mock(namespace=self.namespace)
        api.get.return_value={'metadata':{'labels':{db.OWNER:'foreign'}}}
        with patch.object(db,'namespace'):
            with self.assertRaises(ValueError):telemetry.start(api,self.reference,self.credentials,None)
        api.create.assert_not_called()

    def test_missing_pvc_never_recreated_under_existing_deployment(self):
        api=Mock(namespace=self.namespace)
        def get(kind,name,namespace=None):
            if kind=='deployment' and name=='loki':return {'metadata':{'name':name}}
            return None
        api.get.side_effect=get
        with patch.object(db,'namespace'):
            with self.assertRaises(ValueError):telemetry.start(api,self.reference,self.credentials,None)
        api.create.assert_not_called()

    def test_stop_selector_cannot_match_node(self):
        api=Mock(namespace=self.namespace)
        api.get.return_value={'metadata':{'labels':{db.OWNER:db.identity(self.credentials)},'uid':'one','resourceVersion':'1'}}
        api.run.return_value='{"items":[{"metadata":{"labels":{"'+telemetry.DISABLED+'":"'+db.identity(self.credentials)+'"}}}]}'
        with self.assertRaises(ValueError):telemetry.collector_switch(api,self.credentials,False)
        self.assertFalse(any(c.args[0][0]=='patch' for c in api.run.call_args_list))

    def test_no_prototype_namespace(self):
        with self.assertRaises(ValueError):telemetry.infra_namespace(db.NS)
