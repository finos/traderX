import copy
import json
import unittest
from unittest.mock import patch

from cryptography.hazmat.primitives.asymmetric import rsa
import jwt

import verify_processor_image as campaign


class ProcessorImageTests(unittest.TestCase):
    def test_service_tokens_bind_distinct_execution_audience_and_exact_subject(self):
        key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        alternate = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        def verify(value):
            return jwt.decode(value, key.public_key(), algorithms=['RS256'], issuer=campaign.ISSUER,
                              audience=campaign.AUDIENCE)
        claims = verify(campaign.token(key))
        self.assertEqual(claims['sub'], campaign.MATCHER_SUBJECT)
        self.assertEqual(claims['aud'], 'traderx-execution')
        self.assertNotEqual(verify(campaign.token(key, 'wrong_subject'))['sub'], campaign.MATCHER_SUBJECT)
        for variant, signing, error in (
                ('malformed', key, jwt.DecodeError), ('invalid_signature', alternate, jwt.InvalidSignatureError),
                ('foreign_audience', key, jwt.InvalidAudienceError), ('foreign_issuer', key, jwt.InvalidIssuerError),
                ('expired', key, jwt.ExpiredSignatureError)):
            with self.assertRaises(error): verify(campaign.token(signing, variant))
        with self.assertRaises(ValueError): campaign.token(key, 'unapproved')

    def test_processor_configuration_has_no_browser_entitlements_or_alternate_endpoints(self):
        fixture = {'identities': {'trade-processor': {'username': 'lab_trade_processor', 'password': 'a'*32}}}
        value = campaign.config(fixture, 'b'*32)
        self.assertEqual(value['role'], 'trade-processor')
        self.assertEqual(value['database'], {'host': 'database', 'port': 5432, 'name': 'traderx',
                                           'username': 'lab_trade_processor', 'password': 'a'*32})
        self.assertEqual(value['identity']['audience'], 'traderx-execution')
        self.assertEqual(value['identity']['matcher_subject'], 'lab-matcher-service')
        self.assertNotIn('entitlements.properties', campaign.KEYS)
        self.assertEqual(set(value), {'version', 'role', 'database', 'identity', 'tls'})

    def test_settlement_claim_requires_every_independent_authoritative_effect_once(self):
        value = {name: 1 for name in ('receipts', 'receiptMatches', 'tradeMatches', 'positionMatches', 'orderMatches')}
        self.assertTrue(campaign.settled_once(value))
        for name in value:
            for bad in (0, 2, True, '1', None):
                self.assertFalse(campaign.settled_once(dict(value, **{name: bad})))
            changed = dict(value); changed.pop(name)
            self.assertFalse(campaign.settled_once(changed))

    def test_outbox_proof_binds_execution_account_kinds_payloads_and_no_delivery_claim(self):
        execution = '00000000-0000-4000-8000-000000000001'
        events = [{'id': execution+':trade', 'execution': execution, 'kind': 'trade.settled',
                   'topic': '/accounts/62654/trades', 'account': 62654, 'quantity': 2, 'delivered': None, 'attempts': 0},
                  {'id': execution+':position', 'execution': execution, 'kind': 'position.updated',
                   'topic': '/accounts/62654/positions', 'account': 62654, 'quantity': 2, 'delivered': None, 'attempts': 0}]
        self.assertTrue(campaign.outbox_matches(events, execution))
        for name, bad in (('id', 'unrelated'), ('execution', 'unrelated'), ('account', 22214),
                          ('topic', '/accounts/22214/trades'), ('quantity', 100), ('delivered', 'timestamp'), ('attempts', 1)):
            changed = copy.deepcopy(events); changed[0][name] = bad
            self.assertFalse(campaign.outbox_matches(changed, execution))
        self.assertFalse(campaign.outbox_matches(events[:1], execution))
        self.assertFalse(campaign.outbox_matches(events+events[:1], execution))

    def test_snapshot_includes_receipts_and_outbox_as_well_as_business_tables(self):
        queries = []
        fixture = {'sql': object(), 'database_password': 'private',
                   'admin': lambda query: queries.append(query) or '0|empty'}
        with patch.object(campaign, 'fingerprint', return_value={'trades': '0|empty', 'positions': '0|empty'}):
            value = campaign.snapshot(fixture)
        self.assertEqual(set(value), {'trades', 'positions', 'execution_reservations', 'execution_receipts', 'execution_events'})
        self.assertTrue(all('md5(string_agg' in query for query in queries))

    def test_correct_main_settlement_cannot_hide_unrelated_row_mutation_or_changed_reservation(self):
        observation = {name: 1 for name in ('receipts', 'receiptMatches', 'tradeMatches', 'positionMatches', 'orderMatches')}
        baseline = {name: '2|before-hash' for name in
                    ('accounts', 'accountusers', 'trades', 'positions', 'orderbook', 'lab_execution.reservations')}
        self.assertTrue(campaign.isolated_settlement(observation, baseline, dict(baseline)))
        for table in baseline:
            # The row count and every expected main effect remain correct. A
            # changed unrelated row still changes its full-row fingerprint.
            changed = dict(baseline, **{table: '2|after-hash'})
            self.assertTrue(campaign.settled_once(observation))
            self.assertFalse(campaign.isolated_settlement(observation, baseline, changed), table)
        incomplete = dict(baseline); incomplete.pop('lab_execution.reservations')
        self.assertFalse(campaign.isolated_settlement(observation, incomplete, incomplete))

    def test_protected_snapshot_excludes_only_exact_authorized_business_rows(self):
        execution = '00000000-0000-4000-8000-000000000001'
        queries = []
        value = campaign.protected_snapshot({'admin': lambda query: queries.append(query) or '0|empty'}, execution)
        self.assertEqual(len(value), 6)
        by_table = dict(zip(value, queries))
        self.assertIn("WHERE id <> '"+execution+"'", by_table['trades'])
        self.assertIn("WHERE NOT (accountid=62654 AND security='IBM')", by_table['positions'])
        self.assertIn("WHERE orderid <> 'processor-image-main'", by_table['orderbook'])
        for table in ('accounts', 'accountusers', 'lab_execution.reservations'):
            self.assertNotIn('WHERE', by_table[table])
        with self.assertRaises(ValueError): campaign.protected_snapshot({'admin': self.fail}, "invalid' OR true")

    def test_failure_never_copies_private_exceptions_or_unreviewed_check_names(self):
        for error in (RuntimeError('private-password'), campaign.Failure('private-password')):
            result = campaign.failure(error)
            self.assertEqual(result['error'], 'processor_image_campaign_failed')
            self.assertNotIn('private-password', json.dumps(result))
        self.assertEqual(campaign.failure(campaign.Failure('foreign_audience_denied'))['error'], 'foreign_audience_denied')
        with self.assertRaises(ValueError): campaign.phase('private-password')

    def test_shared_fixture_errors_keep_only_bounded_diagnostic_fields(self):
        error = campaign.RuntimeFailure('java_startup_failed')
        error.runtime_diagnostic = {'running': False, 'exit_code': 1, 'oom_killed': False,
            'categories': ['spring_bean_creation', 'private-password'], 'markers': ['configuration_refused', 'private-password'],
            'exception_classes': ['java.lang.IllegalStateException', 'private.PasswordException'],
            'stderr': 'private-password', 'tls_rejection': False}
        value = campaign.failure(error)
        self.assertEqual(value['error'], 'java_startup_failed')
        self.assertEqual(value['runtime']['exception_classes'], ['java.lang.IllegalStateException'])
        self.assertEqual(value['runtime']['categories'], ['spring_bean_creation'])
        self.assertNotIn('private', json.dumps(value))


if __name__ == '__main__': unittest.main()
