import copy
import unittest
import collector_boundary as cb

class CollectorBoundaryTests(unittest.TestCase):
    def reference(self):
        return {'items':[
          {'apiVersion':'apps/v1','kind':'DaemonSet','metadata':{'name':'promtail','namespace':cb.APP},'spec':{'selector':{'matchLabels':{'app':'promtail'}},'template':{'metadata':{'labels':{'app':'promtail'}},'spec':{'containers':[{'name':'promtail','image':'docker.io/timberio/vector@sha256:'+'a'*64}]}}}},
          {'apiVersion':'v1','kind':'ConfigMap','metadata':{'name':'observability-promtail-config','namespace':cb.APP},'data':{'vector.toml':'extra_field_selector = "metadata.namespace=traderx-security-lab"\nendpoint = "http://loki:3100"\n'}}]}
    def test_preserves_source_and_limits_exception(self):
        r=self.reference();before=copy.deepcopy(r);out=cb.render(r)
        self.assertEqual(r,before);self.assertEqual(out,cb.render(r))
        ds=next(x for x in out['items'] if x['kind']=='DaemonSet');p=ds['spec']['template']['spec']
        self.assertEqual(ds['metadata']['namespace'],cb.INFRA)
        self.assertFalse(p['automountServiceAccountToken'])
        self.assertEqual([v['hostPath']['path'] for v in p['volumes'] if 'hostPath' in v],['/var/log/pods'])
        self.assertTrue(p['containers'][0]['volumeMounts'][1]['readOnly'])
        self.assertEqual(p['volumes'][3]['projected']['sources'][0]['serviceAccountToken']['expirationSeconds'],3600)
        cm=next(x for x in out['items'] if x['kind']=='ConfigMap')
        self.assertIn('metadata.namespace='+cb.APP,cm['data']['vector.toml'])
        self.assertIn('loki.'+cb.APP+'.svc.cluster.local',cm['data']['vector.toml'])
    def test_admission_matches_whole_infra_namespace(self):
        policies=[x for x in cb.render(self.reference())['items'] if x['kind']=='ValidatingAdmissionPolicy']
        self.assertEqual(len(policies),2)
        for p in policies:
            self.assertEqual(p['spec']['failurePolicy'],'Fail')
            self.assertEqual(p['spec']['matchConditions'],[{'name':'infra-namespace','expression':'object.metadata.namespace == "'+cb.INFRA+'"'}])
    def test_unpinned_image_rejected(self):
        r=self.reference();r['items'][0]['spec']['template']['spec']['containers'][0]['image']='vector:latest'
        with self.assertRaises(ValueError):cb.render(r)
