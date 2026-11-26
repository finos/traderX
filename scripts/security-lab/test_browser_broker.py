import json
import unittest
import asyncio
from unittest.mock import patch
from browser_broker import BrokerEvents, EventHub, FeedError, MAX_EVENTS, reader_permissions


def event(account=22214, sequence=1):
    execution='00000000-0000-4000-8000-000000000001'
    return json.dumps({'executionId':execution,'eventId':execution+':trade','eventKind':'trade.settled',
        'eventSequence':sequence,'payload':{'accountId':account,'price':99999,'quantity':99999}}).encode()


class BrowserBrokerTests(unittest.TestCase):
    def hub(self):
        hub=EventHub({'reader':{22214},'trader':{62654},'operator':set()},[22214,62654])
        for account in hub.accounts:hub.connection(account,True)
        return hub

    def test_account_isolation_and_no_business_values_or_global_traffic_counter(self):
        hub=self.hub();revision,initial=hub.poll('reader');_,other=hub.poll('trader')
        hub.ingest(62654,'/accounts/62654/trades',event(62654))
        _,unchanged=hub.poll('reader',initial['cursor'],revision)
        self.assertEqual(unchanged,dict(initial,reset=False));self.assertEqual(hub.poll('operator')[1]['events'],[])
        hub.ingest(22214,'/accounts/22214/trades',event())
        _,page=hub.poll('reader',initial['cursor'],revision)
        self.assertEqual(len(page['events']),1);self.assertFalse(page['reset'])
        self.assertEqual(page['events'][0]['accountId'],22214)
        self.assertNotIn('payload',page['events'][0]);self.assertNotIn('99999',json.dumps(page))
        self.assertNotEqual(page['cursor'].split(':')[0],other['cursor'].split(':')[0])

    def test_untrusted_event_subject_envelope_and_unsafe_sequence_are_rejected(self):
        hub=self.hub();_,initial=hub.poll('reader')
        for topic,raw in [('/accounts/62654/trades',event()),('/accounts/22214/trades',event(62654)),
                          ('/accounts/22214/trades',b'{}'),('/accounts/22214/trades',event(sequence=2**53))]:
            with self.assertRaises((ValueError,TypeError)):hub.ingest(22214,topic,raw)
        self.assertEqual(hub.poll('reader',initial['cursor'])[1]['events'],[])

    def test_overflow_and_foreign_or_future_cursor_require_snapshot_reset(self):
        hub=self.hub();_,initial=hub.poll('reader')
        for sequence in range(MAX_EVENTS+1):hub.ingest(22214,'/accounts/22214/trades',event(sequence=sequence+1))
        _,page=hub.poll('reader',initial['cursor']);self.assertTrue(page['reset']);self.assertEqual(page['events'],[])
        _,foreign=hub.poll('trader');self.assertTrue(hub.poll('reader',foreign['cursor'])[1]['reset'])
        future=page['cursor'].split(':')[0]+':99999';self.assertTrue(hub.poll('reader',future)[1]['reset'])

    def test_disconnect_fails_closed_and_reconnect_resets_current_scope(self):
        hub=self.hub();revision,initial=hub.poll('reader');hub.connection(22214,False)
        with self.assertRaises(FeedError) as error:hub.poll('reader',initial['cursor'],revision)
        self.assertEqual(error.exception.status,503)
        hub.connection(22214,True);new_revision,page=hub.poll('reader',initial['cursor'],revision)
        self.assertEqual(new_revision,revision);self.assertTrue(page['reset'])

    def test_revision_change_and_revocation_retire_existing_scope(self):
        hub=self.hub();revision,initial=hub.poll('reader')
        hub.replace_grants('reader',{62654})
        with self.assertRaises(FeedError) as error:hub.poll('reader',initial['cursor'],revision)
        self.assertEqual(error.exception.status,403)
        self.assertNotEqual(hub.poll('reader')[0],revision)
        hub.revoke('reader')
        with self.assertRaises(FeedError):hub.poll('reader')

    def test_cursor_and_private_identity_boundaries(self):
        hub=self.hub()
        for cursor in ('', 'x:0','a'*32+':-1','a'*32+':01','a'*32+':'+('9'*17),0):
            with self.assertRaises(FeedError):hub.poll('reader',cursor)
        with self.assertRaises(FeedError):hub.poll('unknown')
        with self.assertRaises(ValueError):hub.replace_grants('reader',{12345})
        policy=reader_permissions(22214)
        self.assertEqual(policy['publish'],{'deny':['>']})
        self.assertEqual(policy['subscribe']['allow'],['/accounts/22214/trades','/accounts/22214/positions'])
        with self.assertRaises(ValueError):BrokerEvents({'reader':{22214}}, {22214:{'user':'same','password':'x'*32},62654:{'user':'same','password':'y'*32}}, 'tls://localhost:4222','ca.pem')

    def test_fixture_requires_explicit_nonempty_permissions_and_preserves_existing_roles(self):
        from jetstream_fixture import fixture_permissions, permissions
        self.assertEqual(fixture_permissions(),permissions())
        rules=fixture_permissions({'browser-22214':reader_permissions(22214)})
        self.assertEqual(rules['browser-22214']['publish'],{'deny':['>']})
        self.assertEqual({name:rules[name] for name in permissions()},permissions())
        with self.assertRaises(ValueError):fixture_permissions({'publisher':reader_permissions(22214)})
        with self.assertRaises(ValueError):fixture_permissions({'browser-22214':{'publish':{'allow':[]},'subscribe':{'allow':['a']}}})


class BrokerReconnectTests(unittest.IsolatedAsyncioTestCase):
    async def test_closed_connection_is_replaced_and_old_cursor_invalidated(self):
        class Client:
            def __init__(self):self.is_connected=True;self.closed=False;self.topics=[]
            async def subscribe(self,topic,**options):self.topics.append(topic)
            async def flush(self,**options):pass
            async def close(self):self.closed=True;self.is_connected=False
        first,second=Client(),Client()
        identity={'user':'browser-22214','password':'x'*32}
        hub=BrokerEvents({'reader':{22214}},{22214:identity},'tls://localhost:4222','ca.pem')
        async def until(predicate):
            deadline=asyncio.get_running_loop().time()+2
            while not predicate():
                if asyncio.get_running_loop().time()>deadline:self.fail('Reconnect lifecycle timed out')
                await asyncio.sleep(.01)
        with patch('browser_broker.connect_broker',side_effect=[first,second]) as connect:
            task=asyncio.create_task(hub._account(22214,identity))
            try:
                await until(hub.ready);revision,initial=hub.poll('reader')
                first.is_connected=False
                await until(lambda:connect.call_count==2 and hub.ready())
                current,page=hub.poll('reader',initial['cursor'],revision)
                self.assertEqual(current,revision);self.assertTrue(page['reset']);self.assertEqual(page['events'],[])
                self.assertTrue(first.closed)
                self.assertEqual(second.topics,['/accounts/22214/trades','/accounts/22214/positions'])
            finally:
                hub.stopping.set();await asyncio.wait_for(task,2)
        self.assertTrue(second.closed);self.assertFalse(hub.ready())


if __name__=='__main__':unittest.main()
