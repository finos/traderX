import copy
from decimal import Decimal
from types import SimpleNamespace
import unittest
from unittest.mock import AsyncMock
import uuid

import psycopg
from event_delivery import consume_message, decode_event, validate_event
from verify_event_delivery_adversarial import (
    LostAck, LostAckError, canonical_variants, expect_sql_denial, wire_variants,
)


class AdversarialDeliveryTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        execution = str(uuid.uuid4())
        self.topic = '/accounts/22214/trades'
        self.event = {'eventId': execution + ':trade', 'eventSequence': 1,
                      'executionId': execution, 'eventKind': 'trade.settled',
                      'payload': {'accountId': 22214, 'price': Decimal('900719925474099.123')}}

    def test_wire_mutations_are_rejected_at_intended_decoder_layer(self):
        raw = validate_event(self.topic, self.event)
        self.assertEqual(decode_event(self.topic, raw), self.event)
        for label, mutated, expected in wire_variants(raw):
            with self.subTest(label=label), self.assertRaisesRegex(ValueError, '^' + expected + '$'):
                decode_event(self.topic, mutated)

    def test_canonical_mutations_pass_wire_validation_and_do_not_mutate_source(self):
        original = copy.deepcopy(self.event)
        variants = list(canonical_variants(self.event))
        self.assertEqual(len(variants), 4)
        for label, changed in variants:
            with self.subTest(label=label):
                self.assertNotEqual(changed, original)
                self.assertEqual(decode_event(self.topic, validate_event(self.topic, changed)), changed)
        self.assertEqual(self.event, original)

    async def test_sql_denial_requires_exact_state(self):
        async def fail(error):
            raise error
        class CanonicalDenial(psycopg.errors.InvalidParameterValue):
            @property
            def diag(self):
                return SimpleNamespace(message_primary='event unavailable')
        await expect_sql_denial(fail(CanonicalDenial()), 'expected')
        with self.assertRaisesRegex(AssertionError, 'unexpected SQL denial'):
            await expect_sql_denial(fail(psycopg.errors.InsufficientPrivilege()), 'unexpected')
        with self.assertRaisesRegex(AssertionError, 'unexpected SQL denial'):
            await expect_sql_denial(fail(psycopg.errors.InvalidParameterValue('other')), 'wrong diagnostic')
        with self.assertRaisesRegex(AssertionError, 'SQL accepted'):
            await expect_sql_denial(AsyncMock(return_value='duplicate')(), 'accepted')
        with self.assertRaises(OSError):
            await expect_sql_denial(fail(OSError()), 'transport')

    async def test_lost_ack_occurs_only_after_store_result(self):
        store = AsyncMock()
        store.consume.return_value = 'applied'
        message = type('Message', (), {'subject': self.topic, 'data': validate_event(self.topic, self.event)})()
        with self.assertRaises(LostAckError):
            await consume_message(store, LostAck(message))
        store.consume.assert_awaited_once()

    async def test_malformed_wire_does_not_reach_store_or_ack(self):
        store = AsyncMock()
        raw = wire_variants(validate_event(self.topic, self.event))[0][1]
        message = type('Message', (), {'subject': self.topic, 'data': raw, 'ack_sync': AsyncMock()})()
        with self.assertRaisesRegex(ValueError, 'Duplicate JSON field'):
            await consume_message(store, message)
        store.consume.assert_not_awaited()
        message.ack_sync.assert_not_awaited()


if __name__ == '__main__':
    unittest.main()
