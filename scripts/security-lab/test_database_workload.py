import copy
import unittest
import database_workload as db

class DatabaseWorkloadTests(unittest.TestCase):
    def reference(self):
        return {'items':[{'apiVersion':'apps/v1','kind':'Deployment','metadata':{'name':'database','namespace':db.NS},'spec':{'template':{'metadata':{'labels':{'app':'database'}},'spec':{'containers':[{'name':'database','image':'example@sha256:'+'a'*64,'env':[{'name':'POSTGRES_DB','value':'traderx'},{'name':'POSTGRES_USER','value':'traderx'},{'name':'POSTGRES_PASSWORD','value':'demo'}]}],'volumes':[{'name':'db-data','emptyDir':{}},{'name':'database-init-sql','configMap':{'name':'database-init-sql'}}]}}}}]}
    def test_isolated_render_and_storage(self):
        r=self.reference();before=copy.deepcopy(r);result=db.render(r)
        self.assertEqual(r,before);self.assertEqual(result,db.render(r))
        d=next(x for x in result['items'] if x['kind']=='Deployment');p=d['spec']['template']['spec']
        self.assertEqual(p['securityContext']['runAsUser'],70)
        self.assertEqual(d['spec']['strategy'],{'type':'Recreate'})
        self.assertFalse(p['automountServiceAccountToken'])
        self.assertEqual(p['volumes'][0]['persistentVolumeClaim']['claimName'],db.PVC)
        self.assertTrue(p['containers'][0]['securityContext']['readOnlyRootFilesystem'])
        cm=next(x for x in result['items'] if x['kind']=='ConfigMap');self.assertNotIn('sql',' '.join(cm['data']).lower())
    def test_reject_unreviewed_layout(self):
        r=self.reference();r['items'][0]['spec']['template']['spec']['volumes'][0]={'name':'db-data','hostPath':{'path':'/'}}
        with self.assertRaises(ValueError): db.render(r)
