from contextlib import redirect_stdout,redirect_stderr
import http.client
import io
import json
from pathlib import Path
import ssl
import subprocess
import tempfile
import unittest
from unittest.mock import AsyncMock,Mock,patch
from urllib.parse import urlencode,urlsplit

import jwt
import matcher_image_fixture as fixture
import worker_image_fixture as peers


class MatcherImageFixtureTests(unittest.TestCase):
    def peer(self,root):return fixture.TokenPeer('127.0.0.1',Path(root)/'issuer').start()
    def request(self,peer,body,headers=None,path=fixture.TOKEN_PATH):
        context=ssl.create_default_context(cafile=peer.ca);context.verify_flags|=ssl.VERIFY_X509_STRICT
        connection=http.client.HTTPSConnection('127.0.0.1',peer.server.server_port,context=context,timeout=3)
        try:
            values={'Content-Type':'application/x-www-form-urlencoded',**(headers or {})}
            connection.request('POST',path,body=body,headers=values)
            response=connection.getresponse();return response.status,json.loads(response.read(4097))
        finally:connection.close()
    def form(self,peer,**changes):
        return urlencode(dict(grant_type='client_credentials',client_id=fixture.CLIENT_ID,client_secret=peer.client_secret,**changes)).encode()

    def test_real_verified_https_token_requires_exact_client_and_has_scoped_claims(self):
        with tempfile.TemporaryDirectory() as root:
            peer=self.peer(root)
            try:
                status,response=self.request(peer,self.form(peer))
                self.assertEqual(status,200);self.assertEqual(response['token_type'],'Bearer');self.assertEqual(response['expires_in'],60)
                claims=jwt.decode(response['access_token'],peer.signing_key.public_key(),algorithms=['RS256'],issuer=peer.issuer,audience=fixture.AUDIENCE)
                self.assertEqual(claims['sub'],fixture.SUBJECT);self.assertEqual(claims['exp']-claims['iat'],60)
                for key in ('client_id','client_secret'):
                    values={'grant_type':'client_credentials','client_id':fixture.CLIENT_ID,'client_secret':peer.client_secret};values[key]='wrong-fixture-value'
                    self.assertEqual(self.request(peer,urlencode(values).encode()),(401,{'error':'invalid_client'}))
                self.assertEqual(peer.counts(),{'accepted':1,'rejected':2,'invalid_request':0})
                self.assertNotIn(peer.client_secret,json.dumps(peer.counts()))
            finally:peer.close()
            self.assertFalse(peer.thread.is_alive())

    def test_unknown_duplicate_oversized_malformed_and_wrong_path_are_refused_without_logs(self):
        with tempfile.TemporaryDirectory() as root:
            peer=self.peer(root);output=io.StringIO()
            try:
                valid=self.form(peer)
                invalid=[valid+b'&client_id=duplicate',valid+b'&scope=admin',b'grant_type=client_credentials&client_id=only',
                         b'not-form',b'x'*4097,valid.replace(b'client_credentials',b'password')]
                with redirect_stdout(output),redirect_stderr(output):
                    for body in invalid:self.assertEqual(self.request(peer,body)[0],400)
                    self.assertEqual(self.request(peer,valid,{'Content-Type':'application/json'})[0],400)
                    self.assertEqual(self.request(peer,valid,{'Authorization':'Basic private'})[0],400)
                    self.assertEqual(self.request(peer,valid,{'Host':'wrong.example'})[0],404)
                    self.assertEqual(self.request(peer,valid,path='/other')[0],404)
                self.assertEqual(output.getvalue(),'');self.assertEqual(peer.counts()['accepted'],0)
                self.assertEqual(peer.counts()['invalid_request'],10)
            finally:peer.close()

    def test_request_budget_and_gateway_binding_are_not_public(self):
        with tempfile.TemporaryDirectory() as root:
            with self.assertRaises(ValueError):fixture.TokenPeer('0.0.0.0',Path(root)/'bad')
            peer=self.peer(root)
            try:
                peer.requests=256
                self.assertEqual(self.request(peer,self.form(peer)),(503,{'error':'invalid_request'}))
                self.assertEqual(peer.server.server_address[0],'127.0.0.1')
                context=ssl.create_default_context(cafile=peer.ca)
                import socket
                with socket.create_connection(peer.server.server_address,timeout=3) as raw:
                    with self.assertRaises(ssl.SSLCertVerificationError):context.wrap_socket(raw,server_hostname='wrong-host')
            finally:peer.close()

    def test_network_gateway_requires_owned_internal_single_private_pool(self):
        f={'docker':Mock(),'network':'owned','owner':'owner','gateway':'172.28.240.1'}
        good={'Driver':'bridge','Internal':True,'IPAM':{'Config':[{'Subnet':'172.28.240.0/24','Gateway':'172.28.240.1'}]}}
        with patch.object(peers,'owned',return_value=good):self.assertEqual(fixture.verified_gateway(f),'172.28.240.1')
        for value in ({**good,'Internal':False},{'Internal':True,'IPAM':{'Config':None}},
                      {'Internal':True,'IPAM':{'Config':[{'Subnet':'172.28.240.0/24','Gateway':'172.28.240.2'}]}}):
            with patch.object(peers,'owned',return_value=value),self.assertRaises(ValueError):fixture.verified_gateway(f)

    def test_additional_broker_grants_preserve_baseline_and_scope_matcher(self):
        passwords={name:'synthetic' for name in peers.fixture_permissions(fixture.BROKER_PERMISSIONS)}
        config=peers.peer_config(passwords,extra_permissions=fixture.BROKER_PERMISSIONS)
        users={user['user']:user for user in config['authorization']['users']}
        original=peers.peer_config(passwords)
        for user in original['authorization']['users']:self.assertEqual(users[user['user']],user)
        self.assertEqual(users['matcher']['permissions'],fixture.BROKER_PERMISSIONS['matcher'])
        self.assertEqual(users['matcher']['permissions']['publish']['allow'],['/accounts/62654/orders'])
        self.assertNotIn('/accounts/62654/trades',users['matcher']['permissions']['publish']['allow'])
        denied=peers.peer_config(passwords,False,fixture.BROKER_PERMISSIONS)
        matcher=next(user for user in denied['authorization']['users'] if user['user']=='matcher')
        self.assertEqual(matcher,users['matcher'])

    def test_broker_counter_and_prohibited_publication_export_no_private_details(self):
        f={'docker':Mock(return_value=subprocess.CompletedProcess([],0,'private-password\nAuthentication error - User matcher\nAuthorization Violation\n','')),
           'owner':'owner','broker':{'container_name':'owned','host_endpoint':'tls://172.28.240.3:4222','ca':Path('/ca'),
                                   'passwords':{'matcher':'private-password'}}}
        with patch.object(peers,'owned'):
            self.assertEqual(fixture.broker_auth_rejections(f),2)
        with patch.object(peers,'permission_probe',return_value=False) as probe:
            self.assertTrue(fixture.matcher_publication_denied(f))
            probe.assert_called_once_with('172.28.240.3',Path('/ca'),'private-password',user='matcher',subject='/accounts/62654/trades')
        with patch.object(peers,'permission_probe',return_value=True):self.assertFalse(fixture.matcher_publication_denied(f))
        with patch.object(peers,'owned',side_effect=RuntimeError('private-password')):
            with self.assertRaises(fixture.MatcherFixtureFailure) as failure:fixture.broker_auth_rejections(f)
            self.assertNotIn('private-password',str(failure.exception));self.assertEqual(failure.exception.stage,'broker_diagnostics')

    def test_order_observer_is_readonly_exact_scope_and_bounds_decoded_evidence(self):
        rules=fixture.BROKER_PERMISSIONS['order-observer']
        self.assertEqual(rules,{'publish':{'deny':['>']},'subscribe':{'allow':['/accounts/62654/orders']}})
        observer=fixture.OrderObserver({})
        def wire(event,**changes):
            return json.dumps(dict({'topic':'/accounts/62654/orders','type':'OrderResponse','payload':event,
                                    'date':0,'from':'order-matcher'},**changes)).encode()
        event={'orderId':'fixture-order-1','accountId':62654,'status':'FILLED','private-field':'never-export'}
        observer.receive(wire(event));observer.receive(wire(event))
        self.assertEqual(observer.events(),[{'orderId':'fixture-order-1','status':'FILLED','accountId':62654}])
        self.assertTrue(observer.observed('fixture-order-1','FILLED'))
        self.assertFalse(observer.observed('fixture-order-1','NEW'))
        self.assertNotIn('never-export',json.dumps(observer.events()))
        for index in range(127):observer.receive(wire(dict(event,orderId='bounded-'+str(index))))
        self.assertEqual(len(observer.events()),128)
        observer.receive(wire(dict(event,orderId='overflow')))
        with self.assertRaises(fixture.MatcherFixtureFailure):observer.events()
        for raw in (wire(dict(event,accountId=22214)),wire(dict(event,status='INVENTED')),
                    wire(event,topic='/accounts/22214/orders'),wire(event,type='Trade'),json.dumps(event).encode(),
                    b'{"topic":"/accounts/62654/orders","type":"OrderResponse","date":0,"from":"order-matcher","payload":{"orderId":"a","orderId":"b","accountId":62654,"status":"NEW"}}',b'x'*8193):
            with self.assertRaises((ValueError,UnicodeError)):fixture.order_summary(raw)

    def test_observer_starts_after_verified_subscription_and_closes_client(self):
        f={'broker':{'host_endpoint':'tls://172.28.240.3:4222','passwords':{'order-observer':'private-password'},'ca':Path('/ca')}}
        connection=AsyncMock()
        async def subscribe(subject,cb):
            await cb(Mock(data=b'{"topic":"/accounts/62654/orders","type":"OrderResponse","date":0,"from":"order-matcher","payload":{"orderId":"owned","accountId":62654,"status":"CANCELED"}}'))
        connection.subscribe.side_effect=subscribe
        with patch.object(fixture,'connect_broker',new=AsyncMock(return_value=connection)) as connect:
            observer=fixture.OrderObserver(f).start()
            try:
                connection.flush.assert_awaited_once_with(timeout=3)
                self.assertTrue(observer.observed('owned','CANCELED'))
                self.assertEqual(connect.call_args.args[:4],('tls://172.28.240.3:4222','order-observer','private-password',Path('/ca')))
                self.assertEqual(connection.subscribe.call_args.args,('/accounts/62654/orders',))
            finally:observer.close()
            connection.close.assert_awaited_once();self.assertFalse(observer.thread.is_alive())

    def test_local_wrapper_guard_prevents_any_owned_resource_start(self):
        with patch.object(peers.portability,'isolated_linux',return_value=False),patch.object(fixture,'TokenPeer') as server:
            with self.assertRaises(peers.FixtureFailure):
                with fixture.fixture(Path('/unused')):pass
            server.assert_not_called()
        for price in (True,0,-1,float('nan'),float('inf'),1000001):
            with self.assertRaises(ValueError):fixture.publish_price({},price)


if __name__=='__main__':unittest.main()
