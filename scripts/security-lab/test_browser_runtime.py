import datetime
import http.client
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import socket
import ssl
import tempfile
import threading
import time
import unittest
from unittest.mock import Mock, patch
import urllib.parse

import jwt
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import NameOID

from browser_assets import PublicAssets
from browser_api import ApiProxy
from browser_runtime import broker_policy, load_config, serve
from browser_session import BrowserServer, SESSION, ORIGIN
from test_browser_assets import assets


def signing_keys(key,kid='fixture'):
    value=json.loads(jwt.algorithms.RSAAlgorithm.to_jwk(key.public_key()))
    return {'keys':[dict(value,kid=kid,use='sig',alg='RS256')]}


class RuntimeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.signing=rsa.generate_private_key(public_exponent=65537,key_size=2048)
        cls.jwks=signing_keys(cls.signing)

    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)
        self.static=self.root/'public';self.static.mkdir();assets(self.static)
        self.key=self.root/'server.key';self.cert=self.root/'server.crt'
        self.key.write_bytes(self.signing.private_bytes(serialization.Encoding.PEM,serialization.PrivateFormat.PKCS8,serialization.NoEncryption()))
        self.key.chmod(0o600)
        subject=x509.Name([x509.NameAttribute(NameOID.COMMON_NAME,'localhost')])
        now=datetime.datetime.now(datetime.timezone.utc)
        cert=(x509.CertificateBuilder().subject_name(subject).issuer_name(subject).public_key(self.signing.public_key())
              .serial_number(x509.random_serial_number()).not_valid_before(now-datetime.timedelta(minutes=1))
              .not_valid_after(now+datetime.timedelta(hours=1)).add_extension(x509.SubjectAlternativeName([x509.DNSName('localhost')]),critical=False)
              .add_extension(x509.BasicConstraints(ca=True,path_length=None),critical=True).sign(self.signing,hashes.SHA256()))
        self.cert.write_bytes(cert.public_bytes(serialization.Encoding.PEM))
        with socket.socket() as sock:sock.bind(('127.0.0.1',0));self.port=sock.getsockname()[1]
        self.config=dict(version=1,origin=f'https://localhost:{self.port}',issuer='https://identity.example.test:8443/realms/private',
            client_id='custom-browser',audience='custom-api',listen_host='127.0.0.1',listen_port=self.port,
            certificate=str(self.cert),key=str(self.key),ca_file=str(self.cert),static_root=str(self.static),
            backends={'order-matcher':'https://matcher.example.test:8082'})
        self.path=self.root/'config.json';self.write_config()
        self.context=ssl.create_default_context(cafile=self.cert)

    def write_config(self):
        self.path.write_text(json.dumps(self.config));self.path.chmod(0o600)

    def start(self):
        server=BrowserServer(self.cert,self.key,self.context,self.jwks,
            origin=self.config['origin'],issuer=self.config['issuer'],client_id=self.config['client_id'],
            audience=self.config['audience'],listen_port=self.port,assets=PublicAssets(self.static),configured=True).start()
        self.addCleanup(server.close);return server

    def request(self,path,headers=None):
        client=http.client.HTTPSConnection('localhost',self.port,context=self.context,timeout=3)
        try:
            client.request('GET',path,headers=headers or {})
            response=client.getresponse()
            return response.status,dict(response.getheaders()),response.read()
        finally:client.close()

    def session(self,server):
        token=jwt.encode(dict(iss=self.config['issuer'],aud=self.config['audience'],sub='trader',iat=int(time.time()),exp=int(time.time())+60),
                         self.signing,algorithm='RS256',headers={'kid':'fixture'})
        server.store.sessions['owned']=dict(token=token,subject='trader',csrf='private-csrf',until=time.time()+60)
        return {'Cookie':SESSION+'=owned'}

    def test_private_config_validates_mode_symlink_duplicates_and_fixed_routes(self):
        self.assertEqual(load_config(self.path),self.config)
        self.path.chmod(0o644)
        with self.assertRaises(ValueError):load_config(self.path)
        self.path.chmod(0o600);link=self.root/'link';link.symlink_to(self.path)
        with self.assertRaises(OSError):load_config(link)
        self.path.write_text('{"version":1,"version":1}')
        with self.assertRaises(ValueError):load_config(self.path)
        for name,value in [('version',True),('listen_host','example.com'),('origin','http://localhost'),
                           ('issuer','https://identity.test/realms/private?override=1'),('backends',{'order-matcher':'http://localhost:8082'}),
                           ('extra','unexpected')]:
            original=dict(self.config);self.config[name]=value;self.write_config()
            with self.assertRaises(ValueError,msg=name):load_config(self.path)
            self.config=original
        self.write_config();self.key.chmod(0o644)
        with self.assertRaises(ValueError):load_config(self.path)

    def test_broker_policy_rejects_ambiguous_account_ids_and_grants(self):
        with self.assertRaises(ValueError):broker_policy({'grants':{'subject':[True]},'identities':{}})
        with self.assertRaises(ValueError):broker_policy({'grants':{'subject':[62654,62654]},'identities':{}})
        with self.assertRaises(ValueError):broker_policy({'grants':{},'identities':{'062654':{}}})
        self.assertEqual(broker_policy({'grants':{'subject':[62654]},'identities':{'62654':{'user':'reader','password':'x'*32}}})[0],{'subject':{62654}})

    def test_verified_tls_static_routes_host_and_no_prototype_backend(self):
        (self.static/'assets').mkdir()
        (self.static/'assets/state-ui.json').write_text('{"state":"security-lab"}')
        server=self.start()
        status,headers,body=self.request('/trade');self.assertEqual(status,200)
        self.assertIn(b'main-ABC12345',body);self.assertIn("script-src 'self';",headers['Content-Security-Policy'])
        self.assertEqual(self.request('/main-ABC12345.js')[0],200)
        status,headers,body=self.request('/assets/state-ui.json')
        self.assertEqual(status,200);self.assertEqual(headers['Content-Type'],'application/json')
        self.assertEqual(json.loads(body),{'state':'security-lab'})
        for path in ('/config.json','/main-ABC12345.js.map','/app.js','/style.css','/%2e%2e/config.json'):
            self.assertEqual(self.request(path)[0],404,path)
        self.assertEqual(self.request('/health/live')[0],200)
        self.assertEqual(self.request('/health/ready')[0],200)
        untrusted=http.client.HTTPSConnection('localhost',self.port,context=ssl.create_default_context(),timeout=3)
        try:
            with self.assertRaises(ssl.SSLCertVerificationError):untrusted.request('GET','/')
        finally:untrusted.close()
        self.assertEqual(self.request('/',{'Host':'other.example'})[0],400)
        self.assertEqual(self.request('/api/account/')[0],401)
        with patch('browser_session.api_request') as legacy:
            self.assertEqual(self.request('/api/account/',self.session(server))[0],404)
            legacy.assert_not_called()
        self.assertEqual(self.request('/api/order-matcher/orders',self.session(server))[0],503)

    def test_instance_oidc_configuration_and_signing_key_drift_fail_closed(self):
        server=self.start();headers=self.session(server)
        self.assertEqual(self.request('/session',headers)[0],200)
        status,reply,_=self.request('/login');self.assertEqual(status,302)
        target=urllib.parse.urlsplit(reply['Location']);query=urllib.parse.parse_qs(target.query)
        self.assertEqual(target.netloc,'identity.example.test:8443')
        self.assertEqual(query['client_id'],['custom-browser']);self.assertEqual(query['redirect_uri'],[self.config['origin']+'/callback'])
        self.assertIn('Secure',reply['Set-Cookie']);self.assertEqual(ORIGIN,'https://localhost:18447')
        server.access.loaded-=10;server.refresh_trust(self.jwks);self.assertTrue(server.trust_ready())
        with self.assertRaises(ValueError):server.refresh_trust(signing_keys(self.signing,'changed-kid'))
        self.assertEqual(server.store.sessions,{});self.assertEqual(server.store.pending,{})
        self.assertEqual(self.request('/health/ready')[0],503);self.assertEqual(self.request('/health/live')[0],200)
        self.assertEqual(self.request('/login')[0],503)
        with self.assertRaises(ValueError):server.refresh_trust(self.jwks)

    def test_expired_key_snapshot_rejects_existing_sessions_and_new_login(self):
        server=self.start();headers=self.session(server)
        server.access.loaded-=301;server.identity.loaded-=301
        self.assertEqual(self.request('/health/ready')[0],503)
        self.assertEqual(self.request('/session',headers)[0],401)
        self.assertEqual(self.request('/login')[0],503)
        server.refresh_trust(self.jwks)
        self.assertEqual(self.request('/health/ready')[0],200)

    def test_idle_tcp_and_partial_http_do_not_block_tls_accept_or_shutdown(self):
        server=self.start()
        plain=socket.create_connection(('127.0.0.1',self.port),timeout=2)
        partial=None
        try:
            # The old listening SSLSocket blocked here until plain closed.
            self.assertEqual(self.request('/health/live')[0],200)
            partial=self.context.wrap_socket(socket.create_connection(('127.0.0.1',self.port),timeout=2),server_hostname='localhost')
            partial.sendall(b'GET /health/live HTTP/1.1\r\n')
            self.assertEqual(self.request('/health/live')[0],200)
            started=time.monotonic();server.close()
            self.assertLess(time.monotonic()-started,2)
            plain.settimeout(1);partial.settimeout(1)
            self.assertEqual(plain.recv(1),b'')
            self.assertEqual(partial.recv(1),b'')
        finally:
            plain.close()
            if partial:partial.close()

    def test_connection_workers_are_bounded_and_release_capacity(self):
        with patch('browser_session.MAX_CONNECTIONS',2),patch('browser_session.CONNECTION_TIMEOUT',0.5):
            server=self.start();clients=[]
            try:
                for _ in range(2):clients.append(socket.create_connection(('127.0.0.1',self.port),timeout=2))
                deadline=time.monotonic()+1
                while time.monotonic()<deadline:
                    with server.server.connections_lock:
                        if len(server.server.connections)==2:break
                    time.sleep(.01)
                with server.server.connections_lock:self.assertEqual(len(server.server.connections),2)
                excess=socket.create_connection(('127.0.0.1',self.port),timeout=1)
                try:
                    excess.settimeout(1);self.assertEqual(excess.recv(1),b'')
                finally:excess.close()
                # Each incomplete handshake expires and returns its worker slot.
                for client in clients:
                    client.settimeout(2);self.assertEqual(client.recv(1),b'')
                deadline=time.monotonic()+1
                while time.monotonic()<deadline:
                    with server.server.connections_lock:
                        if not server.server.connections:break
                    time.sleep(.01)
                with server.server.connections_lock:self.assertEqual(len(server.server.connections),0)
                self.assertEqual(self.request('/health/live')[0],200)
            finally:
                for client in clients:client.close()

    def test_slow_verified_upstream_does_not_block_health_session_or_revocation(self):
        entered=threading.Event();release=threading.Event();results=[]
        class Upstream(BaseHTTPRequestHandler):
            def log_message(self,*_):pass
            def do_GET(self):
                entered.set()
                if not release.wait(3):self.send_error(503);return
                data=b'[]';self.send_response(200)
                self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(data)))
                self.end_headers();self.wfile.write(data)
        upstream=ThreadingHTTPServer(('127.0.0.1',0),Upstream)
        tls=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);tls.load_cert_chain(self.cert,self.key)
        upstream.socket=tls.wrap_socket(upstream.socket,server_side=True)
        serving=threading.Thread(target=upstream.serve_forever,daemon=True);serving.start()
        worker=None
        try:
            server=self.start();headers=self.session(server)
            server.api_proxy=ApiProxy({'order-matcher':f'https://localhost:{upstream.server_port}'},self.context)
            def slow_request():
                try:results.append(self.request('/api/order-matcher/orders',headers)[0])
                except Exception as error:results.append(type(error).__name__)
            worker=threading.Thread(target=slow_request);worker.start()
            self.assertTrue(entered.wait(1))
            started=time.monotonic()
            self.assertEqual(self.request('/health/live')[0],200)
            self.assertEqual(self.request('/session',headers)[0],200)
            self.assertLess(time.monotonic()-started,1)
            client=http.client.HTTPSConnection('localhost',self.port,context=self.context,timeout=1)
            try:
                client.request('POST','/logout',headers={**headers,'Origin':self.config['origin'],'X-CSRF-Token':'private-csrf'})
                response=client.getresponse();self.assertEqual(response.status,200);response.read()
            finally:client.close()
            self.assertEqual(self.request('/session',headers)[0],401)
            self.assertEqual(self.request('/api/order-matcher/orders',headers)[0],401)
            release.set();worker.join(2)
            self.assertFalse(worker.is_alive())
            self.assertEqual(results,[200])  # Authorized in-flight operation may complete.
        finally:
            release.set()
            if worker:worker.join(4)
            upstream.shutdown();upstream.server_close();serving.join(2)

    def test_runtime_shutdown_closes_broker_and_listener(self):
        self.config['broker']=dict(endpoint='tls://broker.example.test:4222',ca_file=str(self.cert),
            grants={'trader':[62654]},identities={'62654':{'user':'reader','password':'x'*32}})
        stopping=threading.Event();stopping.set()
        events=Mock();events.start.return_value=events
        server=Mock();server.start.return_value=server
        with patch('browser_runtime.fetch_keys',return_value=self.jwks),patch('browser_runtime.BrokerEvents',return_value=events),patch('browser_runtime.BrowserServer',return_value=server):
            serve(self.config,stopping)
        events.close.assert_called_once();server.close.assert_called_once()

    def test_transport_failure_does_not_refresh_trust_and_invalid_keys_invalidate(self):
        for error,fatal in ((OSError('private response'),False),(ValueError('private signing material'),True)):
            with self.subTest(fatal=fatal):
                stopping=Mock();stopping.wait.side_effect=[False,True]
                server=Mock(trust_failed=False);server.start.return_value=server
                with patch('browser_runtime.fetch_keys',side_effect=[self.jwks,error]),patch('browser_runtime.BrowserServer',return_value=server),patch('sys.stderr') as stderr:
                    serve(self.config,stopping)
                server.refresh_trust.assert_not_called()
                self.assertEqual(server.invalidate_trust.call_count,int(fatal))
                self.assertNotIn('private',str(stderr.write.call_args_list))
                server.close.assert_called_once()


if __name__=='__main__':unittest.main()
