import json
from decimal import Decimal
from types import SimpleNamespace
import unittest
from unittest.mock import AsyncMock
import uuid
from event_delivery import Publisher, consume_message, decode_event, validate_event, Store


class DeliveryTests(unittest.IsolatedAsyncioTestCase):
    def fixture(self):
        execution = str(uuid.uuid4())
        envelope = dict(eventId=execution+':position',eventSequence=1,executionId=execution,
                        eventKind='position.updated',payload={'accountId':22214,'quantity':1})
        topic = '/accounts/22214/positions'
        row = dict(event_id=envelope['eventId'],event_sequence=1,execution_id=execution,
                   event_kind=envelope['eventKind'],payload=envelope['payload'],topic=topic,lease_token=uuid.uuid4())
        return topic,envelope,row

    async def test_no_sql_ack_on_failed_or_wrong_stream_acceptance(self):
        _,_,row=self.fixture()
        for response in [TimeoutError(),SimpleNamespace(stream='OTHER',seq=1,duplicate=False),SimpleNamespace(stream='SECURITY_EVENTS',seq=0,duplicate=False)]:
            store=AsyncMock();js=AsyncMock()
            if isinstance(response,Exception):js.publish.side_effect=response
            else:js.publish.return_value=response
            with self.assertRaises((TimeoutError,ValueError)):await Publisher(store,js).deliver(row)
            store.acknowledge.assert_not_awaited()

    async def test_sql_ack_failure_retains_same_message_identity_on_retry(self):
        _,_,row=self.fixture();store=AsyncMock();js=AsyncMock()
        store.acknowledge.side_effect=[OSError(),True]
        js.publish.return_value=SimpleNamespace(stream='SECURITY_EVENTS',seq=1,duplicate=True)
        publisher=Publisher(store,js)
        with self.assertRaises(OSError):await publisher.deliver(row)
        self.assertTrue(await publisher.deliver(row))
        self.assertEqual(js.publish.await_args_list[0],js.publish.await_args_list[1])
        self.assertEqual(publisher.metrics['sql_acknowledged'],1)

    async def test_consumer_never_acknowledges_failed_effect(self):
        topic,envelope,_=self.fixture();store=AsyncMock();store.consume.side_effect=OSError()
        message=SimpleNamespace(subject=topic,data=json.dumps(envelope).encode(),ack_sync=AsyncMock())
        with self.assertRaises(OSError):await consume_message(store,message)
        message.ack_sync.assert_not_awaited()

    async def test_consumer_commits_before_ack_and_accepts_duplicate(self):
        topic,envelope,_=self.fixture();steps=[];store=AsyncMock()
        async def effect(*args):steps.append('committed');return 'duplicate'
        async def ack(**kwargs):steps.append('ack')
        store.consume.side_effect=effect
        msg=SimpleNamespace(subject=topic,data=json.dumps(envelope).encode(),ack_sync=ack)
        self.assertEqual(await consume_message(store,msg),'duplicate');self.assertEqual(steps,['committed','ack'])

    async def test_invalid_envelope_and_topic_have_no_effect(self):
        topic,envelope,_=self.fixture();store=AsyncMock()
        for raw in [b'{"eventId":"x","eventId":"y"}',b'x'*8193,json.dumps(envelope).encode()]:
            msg=SimpleNamespace(subject=topic.replace('22214','62654'),data=raw,ack_sync=AsyncMock())
            with self.assertRaises(ValueError):await consume_message(store,msg)
            msg.ack_sync.assert_not_awaited()
        store.consume.assert_not_awaited()

    def test_sequence_bool_nan_and_wrong_id_rejected(self):
        topic,e,_=self.fixture()
        for key,value in [('eventSequence',True),('eventSequence',0),('eventSequence',2**63),('eventId','other'),('payload',{'accountId':22214,'quantity':float('nan')})]:
            with self.assertRaises(ValueError):validate_event(topic,dict(e,**{key:value}))
        self.assertEqual(decode_event(topic,validate_event(topic,e)),e)

    def test_financial_decimal_round_trip_keeps_all_digits(self):
        topic,e,_=self.fixture();e["payload"]["price"]=Decimal("900719925474099.123")
        self.assertEqual(decode_event(topic,validate_event(topic,e)),e)

    def test_broker_manifest_matches_daemon_architecture(self):
        from jetstream_fixture import image_for_arch
        arm=image_for_arch('aarch64');amd=image_for_arch('x86_64')
        self.assertEqual(arm[0],'arm64');self.assertEqual(amd[0],'amd64')
        self.assertNotEqual(arm[1],amd[1])
        self.assertEqual(arm,image_for_arch('arm64'))
        self.assertEqual(amd,image_for_arch('amd64'))
        with self.assertRaises(ValueError):image_for_arch('unreviewed')

    def test_store_refuses_uncommitted_outer_connection(self):
        with self.assertRaises(ValueError):Store(SimpleNamespace(autocommit=False))

if __name__=='__main__':unittest.main()
