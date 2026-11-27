import copy
import unittest

import bootstrap_database as bootstrap
import database_permissions as db


class BootstrapTests(unittest.TestCase):
    def reference(self):
        prefix='\n'.join(f'DROP TABLE IF EXISTS {t};' for t in ('trades','orderbook','accountusers','positions','accounts'))+'\nDROP SEQUENCE IF EXISTS accounts_seq;\n'
        return {'items':[{'kind':'ConfigMap','metadata':{'name':'database-init-sql'},'data':{'001-initialSchema.sql':prefix+'CREATE TABLE accounts (id integer);\nSELECT NOW();\n'}}]}

    def test_guarded_single_transaction_and_stable_seed(self):
        r=self.reference();before=copy.deepcopy(r);creds=bootstrap.credentials()
        sql=bootstrap.render(r,creds)
        self.assertEqual(r,before);self.assertEqual(sql,bootstrap.render(r,creds))
        self.assertTrue(sql.startswith('BEGIN;'));self.assertTrue(sql.endswith('COMMIT;\n'))
        self.assertNotIn('DROP ',sql);self.assertNotIn('NOW()',sql)
        self.assertLess(sql.index('pg_advisory_xact_lock'),sql.index('CREATE TABLE'))
        self.assertLess(sql.index('Bootstrap refuses existing'),sql.index('CREATE TABLE'))
        self.assertEqual(sql.count('COMMIT;'),1)
        self.assertIn("current_database() <> 'traderx'",sql)

    def test_private_credentials_are_distinct_and_scoped(self):
        c=bootstrap.credentials();self.assertEqual(set(c),set(db.GRANTS))
        self.assertEqual(len({v['password'] for v in c.values()}),4)
        for n,v in c.items():
            self.assertEqual(v['username'],db.GRANTS[n]['role'])
            self.assertRegex(v['password'],r'^[0-9a-f]{48}$')

    def test_extra_identity_or_sql_in_password_rejected(self):
        c=bootstrap.credentials();c['unknown']={'username':'x','password':'a'*48}
        with self.assertRaises(ValueError):bootstrap.render(self.reference(),c)
        c=bootstrap.credentials();c['account-service']['password']="'; DROP TABLE accounts;"
        with self.assertRaises(ValueError):bootstrap.render(self.reference(),c)

    def test_unreviewed_seed_commands_rejected(self):
        for extra in ('DROP TABLE x;','TRUNCATE accounts;','COMMIT;','\\i /tmp/other.sql'):
            r=self.reference();r['items'][0]['data']['001-initialSchema.sql']+='\n'+extra
            with self.assertRaises(ValueError):bootstrap.seed_sql(r)

    def test_missing_reset_preamble_rejected(self):
        r=self.reference();r['items'][0]['data']['001-initialSchema.sql']= 'CREATE TABLE accounts (id integer);'
        with self.assertRaises(ValueError):bootstrap.seed_sql(r)
