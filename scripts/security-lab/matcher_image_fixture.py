"""Owned matcher peers with a synthetic bounded HTTPS client-credentials issuer."""
import asyncio
from contextlib import contextmanager
import datetime
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
import http.client
import ipaddress
import json
import math
from pathlib import Path
import secrets
import socket
import ssl
import threading
import time
from urllib.parse import parse_qs,urlsplit

from cryptography import x509
from cryptography.hazmat.primitives import hashes,serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import NameOID,ExtendedKeyUsageOID
import jwt

from event_delivery import connect_broker
import worker_image_fixture as peers

CLIENT_ID='lab-matcher-service'
SUBJECT='lab-matcher-service'
AUDIENCE='traderx-execution'
REALM='/realms/matcher-fixture'
TOKEN_PATH=REALM+'/protocol/openid-connect/token'
BROKER_PERMISSIONS={
    'matcher':{'publish':{'allow':['/accounts/62654/orders']},'subscribe':{'allow':['pricing.*']}},
    'pricing-fixture':{'publish':{'allow':['pricing.IBM']},'subscribe':{'deny':['>']}}}
STAGES=frozenset(('token_start','token_ready','token_cleanup','broker_diagnostics','price_publish','publication_probe'))


class MatcherFixtureFailure(RuntimeError):
    def __init__(self,stage):
        self.stage=stage if stage in STAGES else 'token_start'
        super().__init__('Matcher fixture failed; private details withheld')


def issuer_material(address):
    ip=ipaddress.IPv4Address(address);now=datetime.datetime.now(datetime.timezone.utc)
    root_key=rsa.generate_private_key(public_exponent=65537,key_size=2048)
    name=x509.Name([x509.NameAttribute(NameOID.COMMON_NAME,'Synthetic matcher issuer CA')])
    ca=(x509.CertificateBuilder().subject_name(name).issuer_name(name).public_key(root_key.public_key())
        .serial_number(x509.random_serial_number()).not_valid_before(now-datetime.timedelta(minutes=1)).not_valid_after(now+datetime.timedelta(hours=2))
        .add_extension(x509.BasicConstraints(ca=True,path_length=0),True)
        .add_extension(x509.KeyUsage(False,False,False,False,False,True,True,None,None),True)
        .add_extension(x509.SubjectKeyIdentifier.from_public_key(root_key.public_key()),False)
        .add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(root_key.public_key()),False).sign(root_key,hashes.SHA256()))
    key=rsa.generate_private_key(public_exponent=65537,key_size=2048)
    leaf=(x509.CertificateBuilder().subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME,str(ip))]))
        .issuer_name(name).public_key(key.public_key()).serial_number(x509.random_serial_number())
        .not_valid_before(now-datetime.timedelta(minutes=1)).not_valid_after(now+datetime.timedelta(hours=2))
        .add_extension(x509.BasicConstraints(ca=False,path_length=None),True)
        .add_extension(x509.SubjectAlternativeName([x509.IPAddress(ip)]),False)
        .add_extension(x509.KeyUsage(True,False,True,False,False,False,False,None,None),True)
        .add_extension(x509.SubjectKeyIdentifier.from_public_key(key.public_key()),False)
        .add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(root_key.public_key()),False)
        .add_extension(x509.ExtendedKeyUsage([ExtendedKeyUsageOID.SERVER_AUTH]),False).sign(root_key,hashes.SHA256()))
    return {'ca.pem':ca.public_bytes(serialization.Encoding.PEM),'cert.pem':leaf.public_bytes(serialization.Encoding.PEM),
        'key.pem':key.private_bytes(serialization.Encoding.PEM,serialization.PrivateFormat.PKCS8,serialization.NoEncryption())}


class TokenPeer:
    """Purpose-built fixture, deliberately not an OIDC discovery/rotation server."""
    def __init__(self,address,root):
        address=str(ipaddress.IPv4Address(address))
        if address=='0.0.0.0':raise ValueError('Explicit owned gateway required')
        self.root=Path(root);self.root.mkdir(mode=0o700)
        for name,data in issuer_material(address).items():
            path=self.root/name
            with path.open('xb') as output:output.write(data)
            path.chmod(0o600)
        self.ca=self.root/'ca.pem';self.signing_key=rsa.generate_private_key(public_exponent=65537,key_size=2048)
        self.client_secret=secrets.token_hex(32);self.lock=threading.Lock()
        self.totals={'accepted':0,'rejected':0,'invalid_request':0}
        self.requests=0;self.server=None;self.thread=None
        peer=self
        class Server(ThreadingHTTPServer):
            daemon_threads=True;request_queue_size=4
            def __init__(self,*args):
                self.slots=threading.BoundedSemaphore(4);super().__init__(*args)
            def get_request(self):
                raw,remote=self.socket.accept();raw.settimeout(3)
                return raw,remote
            def process_request(self,request,address):
                if not self.slots.acquire(blocking=False):request.close();return
                try:super().process_request(request,address)
                except BaseException:self.slots.release();raise
            def process_request_thread(self,request,address):
                active=[request]
                def expire():
                    try:active[0].shutdown(socket.SHUT_RDWR)
                    except OSError:pass
                    active[0].close()
                timer=threading.Timer(5,expire);timer.daemon=True
                try:
                    wrapped=peer.context.wrap_socket(request,server_side=True,do_handshake_on_connect=False)
                    active[0]=wrapped;timer.start()
                    with wrapped:
                        wrapped.do_handshake();super().process_request_thread(wrapped,address)
                except (OSError,ValueError):request.close()
                finally:timer.cancel();self.slots.release()
            def handle_error(self,*args):pass
        class Handler(BaseHTTPRequestHandler):
            protocol_version='HTTP/1.1'
            def log_message(self,*args):pass
            def reply(self,status,value):
                data=json.dumps(value,separators=(',',':')).encode()
                self.send_response_only(status);self.send_header('Content-Type','application/json')
                self.send_header('Content-Length',str(len(data)));self.send_header('Cache-Control','no-store')
                self.send_header('Connection','close');self.end_headers();self.wfile.write(data);self.close_connection=True
            def send_error(self,code,message=None,explain=None):self.reply(code,{'error':'invalid_request'})
            def invalid(self,status=400):
                with peer.lock:peer.totals['invalid_request']+=1
                self.reply(status,{'error':'invalid_request'})
            def valid_host(self):
                return self.headers.get_all('Host',[])==[peer.authority]
            def limited(self):
                with peer.lock:peer.requests+=1;excessive=peer.requests>256
                if excessive:self.invalid(503)
                return excessive
            def do_GET(self):
                if self.limited():return
                if self.path!='/health' or not self.valid_host():return self.invalid(404)
                self.reply(200,{'status':'synthetic-token-peer'})
            def do_POST(self):
                if self.limited():return
                if self.path!=TOKEN_PATH or not self.valid_host():return self.invalid(404)
                lengths=self.headers.get_all('Content-Length',[])
                if (len(lengths)!=1 or not lengths[0].isascii() or not lengths[0].isdigit()
                    or not 1<=int(lengths[0])<=4096 or self.headers.get('Transfer-Encoding')
                    or self.headers.get('Authorization')
                    or self.headers.get_all('Content-Type',[])!=['application/x-www-form-urlencoded']):return self.invalid()
                raw=self.rfile.read(int(lengths[0]))
                if len(raw)!=int(lengths[0]):return self.invalid()
                try:
                    form=parse_qs(raw.decode('ascii'),keep_blank_values=True,strict_parsing=True,max_num_fields=3,encoding='utf-8',errors='strict')
                    if set(form)!={'grant_type','client_id','client_secret'} or any(len(v)!=1 for v in form.values()):return self.invalid()
                    if form['grant_type']!=['client_credentials']:return self.invalid()
                    client=form['client_id'][0];secret=form['client_secret'][0]
                    if not client.isascii() or not secret.isascii():return self.invalid()
                except (ValueError,UnicodeError):return self.invalid()
                if not (secrets.compare_digest(client,CLIENT_ID) and secrets.compare_digest(secret,peer.client_secret)):
                    with peer.lock:peer.totals['rejected']+=1
                    return self.reply(401,{'error':'invalid_client'})
                now=int(time.time())
                access=jwt.encode({'iss':peer.issuer,'sub':SUBJECT,'aud':AUDIENCE,'iat':now,'exp':now+60},peer.signing_key,algorithm='RS256')
                with peer.lock:peer.totals['accepted']+=1
                self.reply(200,{'access_token':access,'token_type':'Bearer','expires_in':60})
            def do_PUT(self):
                if not self.limited():self.invalid(405)
            do_DELETE=do_PUT;do_PATCH=do_PUT;do_OPTIONS=do_PUT
        self.context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);self.context.minimum_version=ssl.TLSVersion.TLSv1_2
        self.context.load_cert_chain(self.root/'cert.pem',self.root/'key.pem')
        self.server=Server((address,0),Handler);self.authority=address+':'+str(self.server.server_port)
        self.issuer='https://'+self.authority+REALM;self.token_endpoint='https://'+self.authority+TOKEN_PATH

    def start(self):
        self.thread=threading.Thread(target=self.server.serve_forever,kwargs={'poll_interval':.1},daemon=True)
        self.thread.start()
        context=ssl.create_default_context(cafile=self.ca);context.verify_flags|=ssl.VERIFY_X509_STRICT
        connection=http.client.HTTPSConnection(self.server.server_address[0],self.server.server_port,context=context,timeout=3)
        try:
            connection.request('GET','/health');response=connection.getresponse()
            if response.status!=200 or response.read(1025)!=b'{"status":"synthetic-token-peer"}':raise MatcherFixtureFailure('token_ready')
        finally:connection.close()
        return self

    def counts(self):
        with self.lock:return dict(self.totals)

    def close(self):
        if self.server is None:return
        if self.thread is not None:self.server.shutdown();self.thread.join(timeout=5)
        self.server.server_close()
        acquired=0;deadline=time.monotonic()+5
        try:
            for _ in range(4):
                if not self.server.slots.acquire(timeout=max(0,deadline-time.monotonic())):raise MatcherFixtureFailure('token_cleanup')
                acquired+=1
        finally:
            for _ in range(acquired):self.server.slots.release()
        if self.thread is not None and self.thread.is_alive():raise MatcherFixtureFailure('token_cleanup')
        self.server=None


def verified_gateway(f):
    info=peers.owned(f['docker'],'network',f['network'],f['owner'])
    gateway=str(ipaddress.IPv4Address(f['gateway']));pools=info.get('IPAM',{}).get('Config')
    if not isinstance(pools,list) or len(pools)!=1:raise ValueError('Owned bridge IPAM required')
    subnet=ipaddress.IPv4Network(pools[0]['Subnet'])
    if info.get('Driver')!='bridge' or not peers.verified_network(info,subnet,gateway) or ipaddress.IPv4Address(gateway)!=subnet.network_address+1:
        raise ValueError('Owned gateway mismatch')
    if subnet.prefixlen!=24 or not subnet.is_private:raise ValueError('Owned private bridge required')
    return gateway


def broker_auth_rejections(f):
    try:
        name=f['broker']['container_name'];peers.owned(f['docker'],'container',name,f['owner'])
        logs=f['docker']('logs','--tail','2000',name)
        text=logs.stdout+logs.stderr
        if len(text)>256*1024:raise ValueError('Bounded broker log required')
        return sum(any(marker in line.lower() for marker in ('authentication error','authentication violation','authorization violation')) for line in text.splitlines())
    except Exception:raise MatcherFixtureFailure('broker_diagnostics') from None


def publish_price(f,price=99):
    if type(price) not in (int,float) or not math.isfinite(price) or not 0<price<=1000000:raise ValueError('Bounded synthetic price required')
    async def publish():
        connection=await connect_broker(f['broker']['host_endpoint'],'pricing-fixture',f['broker']['passwords']['pricing-fixture'],f['broker']['ca'])
        try:
            await connection.publish('pricing.IBM',json.dumps({'price':price}).encode());await connection.flush(timeout=3)
        finally:await connection.close()
    try:asyncio.run(publish())
    except Exception:raise MatcherFixtureFailure('price_publish') from None


def matcher_publication_denied(f):
    try:
        return not peers.permission_probe(urlsplit(f['broker']['host_endpoint']).hostname,f['broker']['ca'],
            f['broker']['passwords']['matcher'],user='matcher',subject='/accounts/62654/trades')
    except Exception:raise MatcherFixtureFailure('publication_probe') from None


@contextmanager
def fixture(runtime):
    with peers.fixture(runtime,extra_permissions=BROKER_PERMISSIONS) as f:
        peer=None;stage='token_start'
        try:
            gateway=verified_gateway(f);peer=TokenPeer(gateway,f['private']/'matcher-issuer')
            stage='token_ready';peer.start()
            enriched=dict(f,oauth={'issuer':peer.issuer,'token_endpoint':peer.token_endpoint,'client_id':CLIENT_ID,
                'client_secret':peer.client_secret,'matcher_subject':SUBJECT,'audience':AUDIENCE,'ca':peer.ca,
                'public_key':peer.signing_key.public_key().public_bytes(serialization.Encoding.PEM,serialization.PublicFormat.SubjectPublicKeyInfo),
                'signing_key':peer.signing_key},oauth_counts=peer.counts,
                publish_price=lambda price=99:publish_price(f,price),broker_auth_rejections=lambda:broker_auth_rejections(f),
                matcher_publication_denied=lambda:matcher_publication_denied(f))
            stage='active';yield enriched
        except Exception:
            if stage=='active':raise
            raise MatcherFixtureFailure(stage) from None
        finally:
            if peer is not None:
                try:peer.close()
                except Exception:raise MatcherFixtureFailure('token_cleanup') from None
