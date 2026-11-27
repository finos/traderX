"""Integration tests against the immutable snapshot; fetch-baseline prepares its object."""
import copy
import unittest

import lab
import prepare_runtime
import control_bundle as bundle


class ControlBundleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.reference = prepare_runtime.render_reference(
            lab.read_json(lab.PROFILE/'baseline.lock.json'),
            lab.read_json(lab.PROFILE/'runtime-images.lock.json'), offline=True)

    def test_cumulative_composition_is_repeatable_and_preserves_reference(self):
        before=copy.deepcopy(self.reference)
        candidate,plan=bundle.render(self.reference)
        self.assertEqual(before,self.reference)
        self.assertEqual((candidate,plan),bundle.render(self.reference))
        self.assertEqual(len(plan['application_deployments']),19)
        self.assertEqual(plan['status'],'blocked-for-deployment')
        self.assertIn('fresh-cluster-bootstrap',plan['pending_integrations'])
        self.assertEqual(len(plan['required_secrets']),5)
        self.assertEqual(len([d for d in candidate['items'] if d['kind']=='PersistentVolumeClaim']),5)
        self.assertFalse(any(d['kind']=='Secret' for d in candidate['items']))
        self.assertEqual(len([d for d in candidate['items'] if d['kind']=='ValidatingAdmissionPolicy']),12)

    def test_collector_cutover_and_service_fix_survive_composition(self):
        candidate,_=bundle.render(self.reference);objects=bundle.index(candidate['items'])
        self.assertFalse(set(objects)&bundle.LEGACY)
        svc=objects[('v1','Service',bundle.NS,'api-explorer')]
        self.assertEqual(svc['spec']['ports'][0]['targetPort'],8080)
        self.assertEqual(len([d for d in objects.values() if d['kind']=='ClusterRoleBinding']),1)
        self.assertEqual(objects[('v1','Namespace','',bundle.NS)]['metadata']['labels']['pod-security.kubernetes.io/enforce'],'restricted')

    def test_collision_and_changed_inventory_rejected(self):
        duplicate=copy.deepcopy(self.reference)
        duplicate['items'].append(copy.deepcopy(duplicate['items'][0]))
        with self.assertRaisesRegex(ValueError,'Duplicate'):bundle.render(duplicate)
        extra=copy.deepcopy(self.reference)
        deployment=copy.deepcopy(next(d for d in extra['items'] if d['kind']=='Deployment'))
        deployment['metadata']['name']='unreviewed';extra['items'].append(deployment)
        with self.assertRaisesRegex(ValueError,'inventory'):bundle.render(extra)
        original=copy.deepcopy(self.reference['items'][0]);objects=bundle.index([original])
        with self.assertRaisesRegex(ValueError,'Undeclared'):bundle.overlay(objects,[original],set())

    def test_dangling_storage_and_missing_policy_pair_rejected(self):
        candidate,_=bundle.render(self.reference)
        removed=False;items=[]
        for d in candidate['items']:
            if d['kind']=='PersistentVolumeClaim' and not removed:removed=True;continue
            items.append(d)
        with self.assertRaisesRegex(ValueError,'Dangling'):bundle.validate({'items':items})
        name='traderx-lab-sql-identities'
        items=[d for d in candidate['items'] if d['metadata']['name']!=name]
        with self.assertRaisesRegex(ValueError,'Admission inventory'):bundle.validate({'items':items})

    def test_restored_literal_sql_credential_rejected(self):
        candidate,_=bundle.render(self.reference)
        d=next(d for d in candidate['items'] if d['kind']=='Deployment' and d['metadata']['name']=='account-service')
        env=d['spec']['template']['spec']['containers'][0]['env']
        field=next(e for e in env if e['name']=='DATABASE_DBPASS');field.pop('valueFrom');field['value']='demo'
        with self.assertRaisesRegex(ValueError,'Literal'):bundle.validate(candidate)

    def test_broadened_collector_or_namespace_rejected(self):
        candidate,_=bundle.render(self.reference)
        ds=next(d for d in candidate['items'] if d['kind']=='DaemonSet')
        ds['spec']['template']['spec']['volumes'][1]['hostPath']['path']='/'
        with self.assertRaisesRegex(ValueError,'Collector exception'):bundle.validate(candidate)
        candidate,_=bundle.render(self.reference)
        ns=next(d for d in candidate['items'] if d['kind']=='Namespace' and d['metadata']['name']==bundle.NS)
        ns['metadata']['labels']['pod-security.kubernetes.io/enforce']='baseline'
        with self.assertRaisesRegex(ValueError,'Namespace security'):bundle.validate(candidate)
