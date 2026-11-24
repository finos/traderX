import copy
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import platform_readiness as readiness


class ReadinessTests(unittest.TestCase):
    def fixture(self):
        pins={'kind_node':'kindest/node:v1.35.0@sha256:abc','cilium_running_images':[{'image_id':'quay.io/cilium/cilium@sha256:def'}]}
        observed={'uid':'expected','nodes':{'items':[{'metadata':{'name':readiness.NODE},'status':{'nodeInfo':{'kubeletVersion':'v1.35.0','architecture':'arm64'},'conditions':[{'type':'Ready','status':'True'}]}}]},
            'container':{'Config':{'Image':pins['kind_node'],'Labels':{'io.x-k8s.kind.cluster':'traderx-security-lab'}}},
            'cilium':{'status':{'desiredNumberScheduled':1,'numberReady':1,'updatedNumberScheduled':1}},
            'cilium_pods':{'items':[{'status':{'containerStatuses':[{'name':'cilium-agent','ready':True,'imageID':'quay.io/cilium/cilium@sha256:def'}]}}]}}
        return pins,observed

    def test_reviewed_platform(self):
        pins,observed=self.fixture()
        self.assertTrue(all(readiness.assess_cluster(observed,'expected',pins).values()))

    def test_wrong_cluster_image_and_owner_fail(self):
        pins,observed=self.fixture()
        observed['container']['Config']['Image']='kindest/node:latest'
        observed['container']['Config']['Labels']={}
        checks=readiness.assess_cluster(observed,'different',pins)
        for name in ('cluster_identity','owned_kind_node','pinned_node_image'):self.assertFalse(checks[name])

    def test_unready_wrong_architecture_or_version_fail(self):
        pins,observed=self.fixture()
        for change in ('architecture','version','condition','multiple'):
            with self.subTest(change=change):
                bad=copy.deepcopy(observed);node=bad['nodes']['items'][0]
                if change=='architecture':node['status']['nodeInfo']['architecture']='amd64'
                if change=='version':node['status']['nodeInfo']['kubeletVersion']='v1.34.0'
                if change=='condition':node['status']['conditions']=[]
                if change=='multiple':bad['nodes']['items'].append(copy.deepcopy(node))
                self.assertFalse(all(readiness.assess_cluster(bad,'expected',pins).values()))

    def test_daemonset_readiness_is_not_image_verification(self):
        pins,observed=self.fixture()
        observed['cilium_pods']['items'][0]['status']['containerStatuses'][0]['imageID']='quay.io/cilium/cilium:latest'
        checks=readiness.assess_cluster(observed,'expected',pins)
        self.assertTrue(checks['cilium_ready']);self.assertFalse(checks['observed_cilium_agent_digest'])

    def test_empty_and_unready_cilium_fail(self):
        pins,observed=self.fixture()
        observed['cilium']['status']['numberReady']=0;observed['cilium_pods']['items']=[]
        checks=readiness.assess_cluster(observed,'expected',pins)
        self.assertFalse(checks['cilium_ready']);self.assertFalse(checks['observed_cilium_agent_digest'])

    def test_stopped_platform_never_contacts_cluster(self):
        args=SimpleNamespace(store='/private/store',runtime_dir='/runtime',context=readiness.CONTEXT)
        with patch.object(readiness.platform,'system',return_value='Darwin'),patch.object(readiness.platform,'machine',return_value='arm64'),patch.object(readiness.credential_store,'load'),patch.object(readiness.resource_preflight,'check',return_value={'status':'blocked','reasons':['cluster stopped']}),patch.object(readiness.subprocess,'run') as run:
            result=readiness.inspect(args)
            self.assertEqual(result['status'],'blocked');run.assert_not_called()

    def test_invalid_private_store_never_contacts_cluster(self):
        args=SimpleNamespace(store='/private/store',runtime_dir='/runtime',context=readiness.CONTEXT)
        with patch.object(readiness.credential_store,'load',side_effect=ValueError('private data')),patch.object(readiness.resource_preflight,'check',return_value={'status':'ready'}),patch.object(readiness.subprocess,'run') as run:
            result=readiness.inspect(args)
            self.assertFalse(result['checks']['private_sql_identities']);self.assertNotIn('private data',str(result));run.assert_not_called()

    def test_wrong_uid_stops_before_node_or_cilium_reads(self):
        args=SimpleNamespace(store='/private/store',runtime_dir='/runtime',context=readiness.CONTEXT,kubeconfig='/private/kube config',cluster_uid='expected')
        with patch.object(readiness.platform,'system',return_value='Darwin'),patch.object(readiness.platform,'machine',return_value='arm64'),patch.object(readiness.credential_store,'load'),patch.object(readiness.resource_preflight,'check',return_value={'status':'ready'}),patch.object(readiness.subprocess,'run',return_value=SimpleNamespace(stdout='{"metadata":{"uid":"wrong"}}')) as run:
            result=readiness.inspect(args)
            self.assertEqual(result['status'],'blocked');self.assertFalse(result['checks']['cluster_identity'])
            run.assert_called_once()
            self.assertIn('/private/kube config',run.call_args.args[0])
            self.assertEqual(run.call_args.args[0][-5:],['get','namespace','kube-system','-o','json'])
