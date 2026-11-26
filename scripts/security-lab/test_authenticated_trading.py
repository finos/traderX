import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from identity_fixture import AUDIENCE, realm
from verify_authenticated_trading import (configure_realm, MATCHER_CLIENT, MATCHER_SUBJECT,
    TRADING_AUDIENCE, EXECUTION_AUDIENCE, BROKER_PERMISSIONS, JavaService, wait_for)


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


if __name__=='__main__':unittest.main()
