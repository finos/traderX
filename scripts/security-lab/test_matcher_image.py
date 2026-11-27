import copy
import json
from types import SimpleNamespace
import unittest
from unittest.mock import Mock,patch

from cryptography.hazmat.primitives.asymmetric import rsa
import jwt

import verify_matcher_image as campaign


class MatcherImageTests(unittest.TestCase):
    def fixture(self):
        return {'identities':{role:{'username':name,'password':'d'*32} for role,name in
                (('order-matcher','lab_order_matcher'),('trade-processor','lab_trade_processor'))},
                'oauth':{'issuer':'https://172.28.1.1:18080/realms/matcher-fixture',
                    'token_endpoint':'https://172.28.1.1:18080/realms/matcher-fixture/protocol/openid-connect/token',
                    'client_id':'lab-matcher-service','matcher_subject':'lab-matcher-service',
                    'signing_key':rsa.generate_private_key(public_exponent=65537,key_size=2048)}}

    def test_exact_execution_trust_is_distinct_from_browser_authority(self):
        fixture=self.fixture();configs=campaign.configs(fixture,'m'*32,'p'*32)
        matcher,processor=configs['order-matcher'],configs['trade-processor']
        self.assertEqual(matcher['identity']['audience'],'traderx-api')
        self.assertEqual(processor['identity']['audience'],'traderx-execution')
        self.assertEqual(processor['identity']['matcher_subject'],'lab-matcher-service')
        self.assertEqual(matcher['execution']['token_endpoint'],fixture['oauth']['token_endpoint'])
        self.assertEqual(matcher['execution']['endpoint'],'https://trade-processor:18091/internal/executions/')
        self.assertEqual(matcher['broker'],{'host':'nats-broker','port':4222,'username':'matcher'})
        self.assertNotIn('execution',processor)
        import java_runtime
        java_runtime.validate(matcher,role='order-matcher')
        java_runtime.validate(processor,role='trade-processor')
        raw=campaign.bearer(fixture)
        claims=jwt.decode(raw,fixture['oauth']['signing_key'].public_key(),algorithms=['RS256'],
                          issuer=fixture['oauth']['issuer'],audience='traderx-api')
        self.assertEqual(claims['sub'],'lab-trader')
        with self.assertRaises(jwt.InvalidAudienceError):
            jwt.decode(raw,fixture['oauth']['signing_key'].public_key(),algorithms=['RS256'],audience='traderx-execution')

    def test_created_order_identifier_never_becomes_unchecked_sql(self):
        self.assertEqual(campaign.order_id(b'{"orderId":"ord-013-123"}'),'ord-013-123')
        for value in ('unexpected',"ord-013-1' OR true",'ord-013-'+('1'*25),None):
            with self.assertRaises(ValueError):campaign.order_id(json.dumps({'orderId':value}))

    def test_protected_rows_exclude_only_owned_orders_and_exact_execution_position(self):
        queries=[];fixture={'admin':lambda sql:queries.append(sql) or '0|empty'}
        execution='00000000-0000-4000-8000-000000000001'
        values=campaign.protected(fixture,orders=('ord-013-1','ord-013-2'),execution=execution,reservations=True)
        mapping=dict(zip(values,queries))
        self.assertIn("WHERE id <> '"+execution+"'",mapping['trades'])
        self.assertIn("WHERE NOT (accountid=62654 AND security='IBM')",mapping['positions'])
        self.assertIn("WHERE orderid NOT IN ('ord-013-1','ord-013-2')",mapping['orderbook'])
        for table in ('accounts','accountusers','lab_execution.reservations'):self.assertNotIn('WHERE',mapping[table])
        with self.assertRaises(ValueError):campaign.protected(fixture,orders=("bad'",))
        with self.assertRaises(ValueError):campaign.protected(fixture,execution="bad'")

    def test_bad_broker_password_requires_terminal_app_and_independent_authentication_rejection(self):
        detail={'running':False,'exit_code':1,'oom_killed':False,'categories':['broker_io']}
        app=Mock();app.inspect.return_value={'State':{'Running':False}};app.diagnostics.return_value=detail
        fixture={'broker_auth_rejections':lambda:2}
        self.assertTrue(campaign.broker_rejected(app,Mock(),'wrong_broker_password',1,fixture))
        self.assertFalse(campaign.broker_rejected(app,Mock(),'wrong_broker_password',2,fixture))
        for changed in ({'exit_code':0},{'exit_code':2},{'oom_killed':True},{'categories':['broker_tls']},{'running':True}):
            app.diagnostics.return_value=dict(detail,**changed)
            self.assertFalse(campaign.broker_rejected(app,Mock(),'wrong_broker_password',1,fixture))

    def test_wrong_broker_trust_requires_explicit_tls_not_timeout_or_configuration_error(self):
        app=Mock();app.inspect.return_value={'State':{'Running':False}}
        fixture={'broker_auth_rejections':lambda:0}
        for category,expected in (('broker_tls',True),('broker_io',False),('broker_configuration',False)):
            app.diagnostics.return_value={'running':False,'exit_code':1,'oom_killed':False,'categories':[category]}
            for kind in ('wrong_broker_ca','wrong_broker_hostname'):
                self.assertEqual(campaign.broker_rejected(app,Mock(),kind,0,fixture),expected)

    def test_runtime_diagnostics_never_copy_raw_error_text(self):
        error=RuntimeError('private-password')
        error.runtime_diagnostic={'categories':['broker_tls','private-password'],'exception_classes':['java.io.IOException'],
                                  'running':False,'exit_code':1,'stderr':'private-password'}
        value=campaign.failure(error)
        self.assertIn('broker_tls',value['runtime']['categories'])
        self.assertNotIn('private-password',json.dumps(value))
        with self.assertRaises(ValueError):campaign.phase('private-password')

    def test_pending_reservation_cannot_hide_extra_or_changed_authority(self):
        order='ord-013-1';execution='00000000-0000-4000-8000-000000000001';issuer='https://identity.example.test'
        row={'execution':execution,'order':order,'account':62654,'security':'IBM','side':'Buy','quantity':2,
             'price':99,'subject':'lab-trader','issuer':issuer,'terms':order+'|62654|IBM|Buy|2|100'}
        self.assertTrue(campaign.reservation_matches([row],order,execution,issuer))
        self.assertFalse(campaign.reservation_matches([row,row],order,execution,issuer))
        for name,value in (('price',100),('quantity',3),('account',22214),('subject','operator'),('terms','changed')):
            self.assertFalse(campaign.reservation_matches([dict(row,**{name:value})],order,execution,issuer))

    def test_cancellation_ledger_snapshot_includes_complete_receipt_and_outbox_rows(self):
        queries=[]
        result=campaign.ledger_snapshot({'admin':lambda sql:queries.append(sql) or '0|empty'})
        self.assertEqual(set(result),{'reservations','receipts','events'})
        self.assertTrue(all('to_jsonb(t)' in sql and 'md5(string_agg' in sql and 'WHERE' not in sql for sql in queries))

    def test_bounded_observation_failure_reports_fixed_check_and_sanitized_runtime(self):
        app=Mock();app.diagnostics.return_value={'running':False,'exit_code':1,'categories':['broker_tls','private-secret']}
        name='scoped_order_fill_publication_observed'
        with self.assertRaises(campaign.Failure) as caught:
            campaign.wait_for(lambda:False,seconds=0,check_name=name,app=app)
        result=campaign.failure(caught.exception)
        self.assertEqual(result['error'],name)
        self.assertEqual(result['runtime']['exit_code'],1)
        self.assertNotIn('private-secret',json.dumps(result))
        with self.assertRaises(ValueError):campaign.wait_for(lambda:True,check_name='private-secret')


if __name__=='__main__':unittest.main()
