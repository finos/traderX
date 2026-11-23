import copy
import unittest
import support_workloads as support
import workloads

class SupportWorkloadTests(unittest.TestCase):
    def reference(self):
        items=[]
        for name in support.NAMES:
            config=support.CONFIGS.get(name)
            p={'containers':[{'name':name,'image':'example@sha256:'+'a'*64,'ports':[{'containerPort':80,'name':'http'}]}]}
            if config:
                volume,cm,path,sub=config
                p['volumes']=[{'name':volume,'configMap':{'name':cm}}]
                p['containers'][0]['volumeMounts']=[{'name':volume,'mountPath':path,'subPath':sub}]
            items.append({'apiVersion':'apps/v1','kind':'Deployment','metadata':{'name':name,'namespace':workloads.NS},'spec':{'template':{'metadata':{'labels':{'app':name}},'spec':p}}})
        items.append({'apiVersion':'v1','kind':'Service','metadata':{'name':'api-explorer','namespace':workloads.NS},'spec':{'ports':[{'name':'http','port':8080,'targetPort':80}]}})
        return {'items':items}

    def test_preserves_reference_and_scope(self):
        r=self.reference(); before=copy.deepcopy(r); result=support.render(r)
        self.assertEqual(r,before)
        self.assertEqual(result,support.render(r))
        ds=[x for x in result['items'] if x['kind']=='Deployment']
        self.assertEqual({x['metadata']['name'] for x in ds},set(support.NAMES))
        for d in ds:
            p=d['spec']['template']['spec']; c=p['containers'][0]
            self.assertTrue(c['securityContext']['readOnlyRootFilesystem'])
            self.assertFalse(p['automountServiceAccountToken'])
            self.assertTrue(all('emptyDir' in v or 'configMap' in v for v in p['volumes']))
        service=next(x for x in result['items'] if x['kind']=='Service')
        self.assertEqual(service['spec']['ports'][0]['targetPort'],8080)

    def test_unknown_mount_or_missing_component_rejected(self):
        for case in ('missing','hostpath','wrong-config'):
            r=self.reference()
            if case=='missing': r['items'].pop(0)
            elif case=='hostpath': r['items'][0]['spec']['template']['spec']['volumes'].append({'name':'bad','hostPath':{'path':'/'}})
            else: r['items'][0]['spec']['template']['spec']['volumes'][0]['configMap']['name']='unexpected'
            with self.assertRaises(ValueError): support.render(r)

    def test_pod_policy_covers_label_or_identity_and_debug_subresource(self):
        policy=support.pod_admission(workloads.admission(),workloads.NAMES)[0]
        cond=policy['spec']['matchConditions'][0]['expression']
        self.assertIn(' || ',cond)
        self.assertIn('serviceAccountName',cond)
        self.assertIn('pods/ephemeralcontainers',policy['spec']['matchConstraints']['resourceRules'][0]['resources'])
        self.assertEqual(policy['spec']['failurePolicy'],'Fail')
