import copy
import unittest
import workloads

class WorkloadTests(unittest.TestCase):
    def reference(self):
        return {'items': [{'apiVersion':'apps/v1','kind':'Deployment','metadata':{'name':n,'namespace':workloads.NS},'spec':{'template':{'spec':{'containers':[{'name':n,'image':'example@sha256:'+'a'*64}]}}}} for n in workloads.NAMES]}

    def test_preserves_source_and_reproducible(self):
        source=self.reference(); before=copy.deepcopy(source)
        first=workloads.render(source)
        self.assertEqual(source,before)
        self.assertEqual(first,workloads.render(source))
        self.assertEqual(len(first['items']),18)
        self.assertFalse(any(x['kind']=='Namespace' for x in first['items']))

    def test_every_service_is_restricted(self):
        for d in workloads.render(self.reference())['items']:
            if d['kind']!='Deployment': continue
            p=d['spec']['template']['spec']; c=p['containers'][0]
            self.assertEqual(p['serviceAccountName'],'lab-'+d['metadata']['name'])
            self.assertFalse(p['automountServiceAccountToken'])
            self.assertEqual(p['securityContext']['runAsUser'],10001)
            self.assertTrue(c['securityContext']['readOnlyRootFilesystem'])
            self.assertEqual(c['securityContext']['capabilities']['drop'],['ALL'])
            self.assertEqual(p['volumes'],[{'name':'lab-tmp','emptyDir':{'sizeLimit':'128Mi'}}])
            self.assertEqual(c['image'],'example@sha256:'+'a'*64)

    def test_reject_unreviewed_layouts(self):
        for mutation in ['missing','duplicate','sidecar','volume','namespace']:
            ref=self.reference()
            if mutation=='missing': ref['items'].pop()
            elif mutation=='duplicate': ref['items'].append(copy.deepcopy(ref['items'][0]))
            elif mutation=='sidecar': ref['items'][0]['spec']['template']['spec']['containers'].append({'name':'extra'})
            elif mutation=='volume': ref['items'][0]['spec']['template']['spec']['volumes']=[{'name':'existing'}]
            else: ref['items'][0]['metadata']['namespace']='default'
            with self.assertRaises(ValueError): workloads.render(ref)

    def test_policy_scope_and_fail_closed(self):
        items=workloads.render(self.reference())['items']
        p=next(x for x in items if x['kind']=='ValidatingAdmissionPolicy')
        b=next(x for x in items if x['kind']=='ValidatingAdmissionPolicyBinding')
        self.assertEqual(p['spec']['failurePolicy'],'Fail')
        self.assertEqual(b['spec']['validationActions'],['Deny'])
        self.assertIn(workloads.NS,p['spec']['matchConditions'][0]['expression'])
        self.assertEqual(p['spec']['matchConstraints']['resourceRules'][0]['resources'],['deployments'])
