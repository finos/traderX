import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import os

from authenticated_delivery import matches_notifications, worker_configs
from delivery_worker import validate_config

from identity_fixture import AUDIENCE, realm
from verify_authenticated_trading import (configure_realm, MATCHER_CLIENT, MATCHER_SUBJECT,
    TRADING_AUDIENCE, EXECUTION_AUDIENCE, BROKER_PERMISSIONS, JavaService, wait_for, failure_summary)


class AuthenticatedTradingTests(unittest.TestCase):
    def test_service_grant_is_separate_from_browser_authority(self):
        config=realm({'reader':'fixture-one','trader':'fixture-two','operator':'fixture-three'})
        configure_realm(config,'fixture-service-secret')
        browser,service=config['clients']
        browser_audiences={mapper['config']['included.custom.audience'] for mapper in browser['protocolMappers']}
        self.assertEqual(browser_audiences,{AUDIENCE,TRADING_AUDIENCE})
        self.assertNotIn(EXECUTION_AUDIENCE,browser_audiences)
        self.assertTrue(browser['publicClient']);self.assertFalse(browser['serviceAccountsEnabled'])
        self.assertEqual(service['clientId'],MATCHER_CLIENT);self.assertFalse(service['publicClient'])
        self.assertTrue(service['serviceAccountsEnabled'])
        for name in ('standardFlowEnabled','implicitFlowEnabled','directAccessGrantsEnabled','fullScopeAllowed'):
            self.assertFalse(service[name])
        self.assertEqual(service['protocolMappers'][0]['config']['included.custom.audience'],EXECUTION_AUDIENCE)
        user=next(user for user in config['users'] if user.get('serviceAccountClientId')==MATCHER_CLIENT)
        self.assertEqual(user['id'],MATCHER_SUBJECT);self.assertEqual(user['realmRoles'],[])

    def test_price_producer_cannot_publish_business_events(self):
        self.assertEqual(BROKER_PERMISSIONS['pricing-fixture']['publish']['allow'],['pricing.IBM'])
        self.assertEqual(BROKER_PERMISSIONS['pricing-fixture']['subscribe']['deny'],['>'])
        self.assertEqual(BROKER_PERMISSIONS['matcher']['publish']['allow'],['/accounts/62654/orders'])
        self.assertNotIn('/orders',BROKER_PERMISSIONS['matcher']['publish']['allow'])

    def test_candidate_jar_drift_is_rejected_before_process_start(self):
        with tempfile.TemporaryDirectory() as temp:
            runtime=Path(temp);target=runtime/'trading-security-build/order-matcher/build/libs';target.mkdir(parents=True)
            (target/'candidate.jar').write_bytes(b'changed')
            (runtime/'evidence').mkdir()
            (runtime/'evidence/trading-security-build.json').write_text(json.dumps({'services':[
                {'service':'order-matcher','jar_sha256':'wrong','generation':{'inputs':{}}}]}))
            with patch('verify_authenticated_trading.subprocess.Popen') as launch:
                with self.assertRaisesRegex(ValueError,'Unverified trading jar'):
                    JavaService(runtime,runtime,'order-matcher',{},None,runtime/'trust')
                launch.assert_not_called()

    def test_observation_deadline_fails_instead_of_claiming_success(self):
        with patch('verify_authenticated_trading.time.monotonic',side_effect=[0,0,2]),patch('verify_authenticated_trading.time.sleep'):
            with self.assertRaisesRegex(AssertionError,'missing independent effect'):
                wait_for(lambda:False,'missing independent effect',timeout=1)

    def test_startup_diagnostics_emit_only_fixed_categories(self):
        with tempfile.TemporaryDirectory() as temp:
            log=Path(temp)/'private.log'
            log.write_text('secret-password https://user:credential@private.example/path\nCaused by: org.springframework.beans.factory.BeanCreationException: private body\nAuthenticated broker unavailable; broker-failure=tls\n')
            value=failure_summary(log,'order-matcher')
            self.assertIn('order-matcher startup failed',value)
            self.assertIn('bean-creation',value);self.assertIn('broker-tls',value)
            for secret in ('secret-password','credential','private.example','private body','Caused by',str(log)):
                self.assertNotIn(secret,value)
    def test_delivery_uses_real_worker_contract_and_account_scoped_consumer(self):
        with tempfile.TemporaryDirectory() as temp:
            ca=Path(temp)/'ca.pem';ca.write_text('fixture')
            settings={'endpoint':'tls://localhost:4222','ca':ca,'passwords':{'publisher':'p'*24,'consumer-b':'c'*24}}
            configs=worker_configs(settings,5432,{'event_publisher':'d'*24,'event_consumer_b':'e'*24})
            with patch.dict(os.environ,{},clear=True):
                for config in configs:validate_config(config)
            self.assertEqual(configs[0]['mode'],'publisher')
            self.assertEqual(configs[1]['account_id'],62654);self.assertEqual(configs[1]['durable'],'ACCOUNT_B')
            self.assertEqual(configs[1]['broker_user'],'consumer-b')
            for name in ('browser-reader','browser-trader'):
                self.assertEqual(BROKER_PERMISSIONS[name]['publish'],{'deny':['>']})

    def test_notification_proof_rejects_extra_business_payload_foreign_scope_and_missing_events(self):
        event=dict(eventId='execution:trade',executionId='execution',eventSequence=1,eventKind='trade.settled',
            topic='/accounts/62654/trades',accountId=62654)
        page={'reset':False,'events':[event]};expected={'execution:trade'}
        self.assertTrue(matches_notifications(page,expected))
        for change in ({'payload':{'price':99}},{'accountId':22214},{'topic':'/accounts/22214/trades'},{'eventId':'unexpected'}):
            self.assertFalse(matches_notifications(dict(page,events=[dict(event,**change)]),expected))
        self.assertFalse(matches_notifications(dict(page,reset=True),expected))
        self.assertFalse(matches_notifications(dict(page,events=[]),expected))

    def test_read_api_source_drift_is_rejected_before_launch(self):
        with tempfile.TemporaryDirectory() as temp:
            runtime=Path(temp);target=runtime/'position-service';target.mkdir()
            (target/'build.gradle').write_text('changed source')
            (target/'security-generation.json').write_text(json.dumps({'files':{'build.gradle':'wrong'},'inputs':{}}))
            with patch('verify_authenticated_trading.subprocess.Popen') as launch:
                with self.assertRaisesRegex(ValueError,'Read API generated source drift'):
                    JavaService(runtime,runtime,'position-service',{},None,runtime/'trust')
                launch.assert_not_called()


if __name__=='__main__':unittest.main()
