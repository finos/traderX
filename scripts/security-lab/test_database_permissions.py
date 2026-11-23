import unittest
import database_permissions as db
class GrantsTests(unittest.TestCase):
    def test_grants_are_scoped_and_transactional(self):
        creds={n:{'username':g['role'],'password':'a'*48} for n,g in db.GRANTS.items()};sql=db.grant_sql(creds)
        self.assertTrue(sql.startswith('BEGIN;'));self.assertTrue(sql.endswith('COMMIT;\n'))
        self.assertNotIn('GRANT ALL',sql);self.assertNotIn('TO lab_trade_service',sql)
        self.assertIn('GRANT SELECT ON TABLE public.positions TO lab_position;',sql)
        self.assertNotIn('INSERT ON TABLE public.positions TO lab_position',sql)
        self.assertEqual(sql.count('NOBYPASSRLS'),4)
        creds['account-service']['password']="bad'; DROP TABLE accounts;"
        with self.assertRaises(ValueError):db.grant_sql(creds)
    def test_secret_overlay_is_idempotent_and_preserves_source(self):
        import copy,json
        source={'items':[{'kind':'Deployment','metadata':{'name':n},'spec':{'template':{'spec':{'containers':[{'env':[{'name':'DATABASE_DBUSER','value':'traderx'},{'name':'DATABASE_DBPASS','value':'demo'}]}]}}}} for n in db.NAMES]}
        before=copy.deepcopy(source);first=db.transform(source)
        self.assertEqual(source,before);self.assertEqual(first,db.transform(first))
        self.assertNotIn('"value": "demo"',json.dumps(first))
        for d in first['items']:
            name=d['metadata']['name'];env=d['spec']['template']['spec']['containers'][0]['env']
            for e in env:
                if e['name'].startswith('DATABASE_'):self.assertEqual(e['valueFrom']['secretKeyRef']['name'],db.secret_name(name))
            if name=='order-matcher':self.assertIn({'name':'SPRING_JPA_HIBERNATE_DDL_AUTO','value':'none'},env)
