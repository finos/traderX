"""Bounded loopback HTTPS account browser session; no tokens in page JavaScript."""
import base64
import hashlib
from http.cookies import SimpleCookie
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import re
import secrets
import socket
import ssl
import threading
import time
import urllib.parse
import urllib.request
import urllib.error
from identity_fixture import ISSUER, CLIENT, AUDIENCE, TokenVerifier
from verify_account_authorization import request as api_request
from browser_api import BoundaryError, MAX_BODY, json_body, route

ORIGIN='https://localhost:18447'
CALLBACK=ORIGIN+'/callback'
SESSION='__Host-traderx-session'
TRANSACTION='__Host-traderx-login'
CONNECTION_TIMEOUT=5
MAX_CONNECTIONS=32


class BoundedTLSServer(ThreadingHTTPServer):
    """Accept raw TCP promptly; bound TLS/HTTP workers and close idle sockets."""
    def __init__(self,address,handler,tls):
        self.tls=tls
        self.capacity=threading.BoundedSemaphore(MAX_CONNECTIONS)
        self.connections=set()
        self.connections_lock=threading.Lock()
        self.closing=False
        super().__init__(address,handler)

    def process_request(self,request,client_address):
        with self.connections_lock:
            if self.closing or not self.capacity.acquire(blocking=False):
                self.shutdown_request(request)
                return
            self.connections.add(request)
        try:
            super().process_request(request,client_address)
        except BaseException:
            with self.connections_lock:self.connections.discard(request)
            self.capacity.release()
            self.shutdown_request(request)
            raise

    def process_request_thread(self,request,client_address):
        secure=None
        try:
            # Wrapping without a handshake performs no peer-controlled I/O.
            # Keep the raw-to-TLS ownership transfer atomic with server_close.
            with self.connections_lock:
                if self.closing:return
                request.settimeout(CONNECTION_TIMEOUT)
                secure=self.tls.wrap_socket(request,server_side=True,do_handshake_on_connect=False)
                self.connections.discard(request)
                self.connections.add(secure)
            secure.do_handshake()
            self.finish_request(secure,client_address)
        except (OSError,ValueError):
            # Idle, aborted and malformed connections have no private diagnostics.
            pass
        except Exception:
            self.handle_error(secure or request,client_address)
        finally:
            self.shutdown_request(secure or request)
            with self.connections_lock:
                self.connections.discard(request)
                self.connections.discard(secure)
            self.capacity.release()

    def server_close(self):
        with self.connections_lock:
            self.closing=True
            connections=list(self.connections)
        for connection in connections:
            try:connection.shutdown(socket.SHUT_RDWR)
            except OSError:pass
            connection.close()
        super().server_close()

PAGE='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>TraderX account security lab</title><link rel="stylesheet" href="/style.css"><main><img class="logo" src="/traderx-logo.svg" alt="TraderX"><h1>TraderX account security lab</h1><p>Local identity checkpoint · synthetic accounts only</p><p id="status">Checking session…</p><a href="/login">Sign in with Keycloak</a><button id="accounts">My accounts</button><button id="memberships">My memberships</button><p><label>Test account ID <input id="account" inputmode="numeric" value="62654"></label><button id="check">Check access</button></p><button id="switch">Switch account</button><button id="logout">Sign out of this lab</button><pre id="result" aria-live="polite"></pre><p>Account permissions are enforced by the API. Local sign-out ends this browser session; it does not revoke provider SSO or other issued tokens.</p></main><script src="/app.js"></script></html>'''
JS='''let csrf; const result=document.querySelector('#result'); async function show(path){const r=await fetch(path);result.textContent=`HTTP ${r.status}\\n`+await r.text();} fetch('/session').then(async r=>{if(!r.ok){document.querySelector('#status').textContent='Signed out';return;}const s=await r.json();csrf=s.csrf;document.querySelector('#status').textContent='Signed in as '+s.subject;});document.querySelector('#accounts').onclick=()=>show('/api/account/');document.querySelector('#memberships').onclick=()=>show('/api/accountuser/');document.querySelector('#check').onclick=()=>show('/api/account/'+encodeURIComponent(document.querySelector('#account').value));document.querySelector('#logout').onclick=async()=>{const r=await fetch('/logout',{method:'POST',headers:{'X-CSRF-Token':csrf||''}});if(r.ok)location.href='/';else result.textContent='Sign-out rejected: '+r.status;};'''
JS += "document.querySelector('#switch').onclick=async()=>{const r=await fetch('/switch',{method:'POST',headers:{'X-CSRF-Token':csrf||''}});if(r.ok){const data=await r.json();location.href=data.redirect;}else result.textContent='Switch rejected: '+r.status;};"
CSS='.logo{width:230px;max-width:80%}body{font:17px system-ui;background:#f3f6fa;color:#17263b}main{max-width:850px;margin:4rem auto;padding:2rem;background:white;border-radius:12px}button,a,input{font:inherit;margin:.4rem;padding:.6rem}pre{padding:1rem;background:#eef2f7;white-space:pre-wrap}'

class Store:
    def __init__(self,clock=time.time):self.clock=clock;self.sessions={};self.pending={};self.lock=threading.RLock()
    def prune(self):
        now=self.clock()
        for values in (self.sessions,self.pending):
            for key in list(values):
                if values[key]['until']<=now:del values[key]
    def session(self,key):
        self.prune();return self.sessions.get(key)

class BrowserServer:
    def __init__(self,cert,key,context,jwks,api_proxy=None,broker_events=None,*,
                 origin=ORIGIN,issuer=ISSUER,client_id=CLIENT,audience=AUDIENCE,
                 listen_host='127.0.0.1',listen_port=18447,assets=None,configured=False):
        public=urllib.parse.urlsplit(origin)
        authority=urllib.parse.urlsplit(issuer)
        if public.scheme!='https' or not public.hostname or public.username or public.password or public.path or public.query or public.fragment:
            raise ValueError('HTTPS browser origin required')
        if authority.scheme!='https' or not authority.hostname or authority.username or authority.password or authority.query or authority.fragment or issuer.endswith('/'):
            raise ValueError('HTTPS issuer required')
        if listen_host not in ('127.0.0.1','0.0.0.0') or type(listen_port) is not int or not 1<=listen_port<=65535:
            raise ValueError('Explicit listener required')
        if not re.fullmatch(r'[A-Za-z0-9_.-]{1,128}',client_id) or not isinstance(audience,str) or not audience or len(audience)>128:
            raise ValueError('Explicit client and audience required')
        if not context.check_hostname or context.verify_mode!=ssl.CERT_REQUIRED:raise ValueError('Verified provider TLS required')
        self.origin,self.issuer,self.client_id,self.audience=origin,issuer,client_id,audience
        self.host=public.netloc;self.callback=origin+'/callback';self.assets=assets;self.configured=configured
        self.store=Store();self.access=TokenVerifier(jwks,issuer=issuer,audience=audience)
        self.identity=TokenVerifier(jwks,issuer=issuer,audience=client_id);self.context=context
        self.approved_keys=self.key_fingerprint(self.access);self.trust_failed=False;self.thread=None;self.closed=False
        self.api_proxy=api_proxy
        self.broker_events=broker_events
        owner=self
        class Handler(BaseHTTPRequestHandler):
            def log_message(self,*args):pass
            def reply(self,status,value='',cookie=None,location=None,kind='application/json'):
                data=b'' if status==204 else (json.dumps(value).encode() if kind=='application/json' else value if isinstance(value,bytes) else value.encode())
                self.send_response(status)
                from browser_assets import CSP
                policy=CSP if owner.configured else "default-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'"
                for k,v in {'Content-Type':kind,'Content-Length':str(len(data)),'Cache-Control':'no-store','Referrer-Policy':'no-referrer','X-Content-Type-Options':'nosniff','Content-Security-Policy':policy}.items():self.send_header(k,v)
                if cookie:self.send_header('Set-Cookie',cookie)
                if location:self.send_header('Location',location)
                self.end_headers();self.wfile.write(data)
            def cookie(self,name):
                try:c=SimpleCookie(self.headers.get('Cookie',''));return c[name].value if name in c else ''
                except Exception:return ''
            def do_GET(self):self.dispatch()
            def do_POST(self):self.dispatch()
            def dispatch(self):
                if self.headers.get_all('Host',[])!=[owner.host]:return self.reply(400,'Invalid host')
                path=urllib.parse.urlsplit(self.path).path
                if owner.configured and self.command=='GET' and self.path in ('/health/live','/health/ready'):
                    ready=owner.trust_ready() and (owner.broker_events is None or owner.broker_events.ready())
                    status=200 if self.path=='/health/live' or ready else 503
                    return self.reply(status,{'status':'ok' if status==200 else 'unavailable'})
                # Authorization is atomic, but provider/backend/client I/O must
                # not hold the global store lock. Requests authorized before
                # logout may complete within their existing network timeouts;
                # every subsequent request observes revocation immediately.
                session_key=self.cookie(SESSION)
                with owner.store.lock:
                    session=owner.store.session(session_key)
                    if session:
                        try:owner.access.verify(session['token'])
                        except Exception:
                            owner.store.sessions.pop(session_key,None)
                            session=None
                if path=='/events':
                    if not session:return self.reply(401,'Sign in required')
                    if self.command!='GET':return self.reply(405,'Read-only notification endpoint')
                    if owner.broker_events is None:return self.reply(503,'Notification feed not configured')
                    from browser_broker import FeedError
                    try:
                        parsed=urllib.parse.urlsplit(self.path)
                        if parsed.fragment or len(self.path)>160:raise ValueError('Invalid event query')
                        query=urllib.parse.parse_qs(parsed.query,keep_blank_values=True,strict_parsing=True,max_num_fields=1)
                        if query and set(query)!={'after'}:raise ValueError('Invalid event query')
                        after=query['after'][0] if query else None
                        with owner.store.lock:
                            if owner.store.session(session_key) is not session:raise FeedError(401,'Sign in required')
                            try:
                                # Hub polling only copies bounded in-memory data;
                                # bind the revision atomically across parallel polls.
                                revision,data=owner.broker_events.poll(session['subject'],after,session.get('broker_revision'))
                                session['broker_revision']=revision
                            except FeedError as error:
                                if error.status==403:owner.store.sessions.pop(session_key,None)
                                raise
                        return self.reply(200,data)
                    except FeedError as error:
                        return self.reply(error.status,str(error))
                    except ValueError:return self.reply(400,'Invalid notification query')
                if path.startswith('/api/') and (owner.configured or (owner.api_proxy and not re.fullmatch(r'/api/(account|accountuser)/(\d+)?',path))):
                    if not session:return self.reply(401,'Sign in required')
                    try:
                        selected=route(self.command,self.path)
                        if owner.api_proxy is None:raise BoundaryError(503,'API not configured')
                        body=None
                        if self.command=='POST':
                            if self.headers.get('Origin')!=owner.origin or not secrets.compare_digest(self.headers.get('X-CSRF-Token',''),session['csrf']):return self.reply(403,'CSRF check failed')
                            lengths=self.headers.get_all('Content-Length',[])
                            if self.headers.get('Transfer-Encoding') or len(lengths)!=1 or not re.fullmatch(r'[0-9]+',lengths[0]):raise BoundaryError(400,'Invalid request framing')
                            length=int(lengths[0])
                            if length>MAX_BODY:raise BoundaryError(413,'Request too large')
                            self.connection.settimeout(5)
                            body=self.rfile.read(length)
                            if len(body)!=length:raise BoundaryError(400,'Incomplete request')
                            # Empty cancel commands carry no account override.
                            if not body and selected.path.endswith('/cancel'):body=None
                            else:body=json_body(body,self.headers.get('Content-Type',''))
                        status,data=owner.api_proxy.call(self.command,self.path,session['token'],body)
                        return self.reply(status,data)
                    except BoundaryError as error:return self.reply(error.status,str(error))
                    except (OSError,ValueError):return self.reply(400,'Invalid API request')
                if self.command=='POST':
                    if path not in ('/logout','/switch'):return self.reply(405,'Unsupported method')
                    if not session:return self.reply(401,'Sign in required')
                    if self.headers.get('Origin')!=owner.origin or not secrets.compare_digest(self.headers.get('X-CSRF-Token',''),session['csrf']):return self.reply(403,'CSRF check failed')
                    with owner.store.lock:owner.store.sessions.pop(session_key,None)
                    return self.reply(200,{'redirect':owner.switch_url(owner.origin,owner.issuer,owner.client_id)} if path=='/switch' else 'Signed out',cookie=owner.cookie(SESSION,'',0))
                if owner.assets:
                    asset=owner.assets.get(self.path)
                    if asset:return self.reply(200,asset[0],kind=asset[1])
                if not owner.configured:
                    if path=='/':return self.reply(200,PAGE,kind='text/html; charset=utf-8')
                    if path=='/app.js':return self.reply(200,JS,kind='text/javascript')
                    if path=='/traderx-logo.svg':return self.reply(200,(Path(__file__).resolve().parents[2]/'website/static/img/traderX/TraderX_Horizontal.svg').read_text(),kind='image/svg+xml')
                    if path=='/style.css':return self.reply(200,CSS,kind='text/css')
                if path=='/login':
                    transaction=secrets.token_urlsafe(32);state=secrets.token_urlsafe(32);nonce=secrets.token_urlsafe(32);verifier=secrets.token_urlsafe(48)
                    login_error=None
                    with owner.store.lock:
                        owner.store.prune()
                        if not owner.trust_ready():login_error=(503,'Identity trust unavailable')
                        elif len(owner.store.pending)>=100:login_error=(429,'Too many pending logins')
                        else:owner.store.pending[transaction]=dict(state=state,nonce=nonce,verifier=verifier,until=time.time()+120)
                    if login_error:return self.reply(*login_error)
                    challenge=base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).decode().rstrip('=')
                    query=urllib.parse.urlencode(dict(client_id=owner.client_id,redirect_uri=owner.callback,response_type='code',scope='openid',prompt='login',state=state,nonce=nonce,code_challenge=challenge,code_challenge_method='S256'))
                    return self.reply(302,'',cookie=owner.cookie(TRANSACTION,transaction,120),location=owner.issuer+'/protocol/openid-connect/auth?'+query)
                if path=='/callback':
                    with owner.store.lock:pending=owner.store.pending.pop(self.cookie(TRANSACTION),None)
                    query=urllib.parse.parse_qs(urllib.parse.urlsplit(self.path).query)
                    if not pending or len(query.get('state',[]))!=1 or not secrets.compare_digest(query['state'][0],pending['state']) or len(query.get('code',[]))!=1:return self.reply(400,'Invalid login transaction')
                    try:
                        body=urllib.parse.urlencode(dict(grant_type='authorization_code',client_id=owner.client_id,redirect_uri=owner.callback,code=query['code'][0],code_verifier=pending['verifier'])).encode()
                        from browser_api import NoRedirect
                        opener=urllib.request.build_opener(urllib.request.ProxyHandler({}),urllib.request.HTTPSHandler(context=owner.context),NoRedirect())
                        with opener.open(owner.issuer+'/protocol/openid-connect/token',data=body,timeout=10) as response:
                            raw=response.read(65537)
                            if len(raw)>65536:raise ValueError('Token response too large')
                            tokens=json.loads(raw)
                        with owner.store.lock:
                            access=owner.access.verify(tokens['access_token']);identity=owner.identity.verify(tokens['id_token'])
                            if identity.get('nonce')!=pending['nonce'] or identity['sub']!=access['sub']:raise ValueError('Invalid identity')
                            if len(owner.store.sessions)>=100:raise ValueError('Session capacity')
                            owner.store.sessions.pop(self.cookie(SESSION),None)
                            sid=secrets.token_urlsafe(32)
                            until=min(access['exp'],identity['exp'],time.time()+300)
                            owner.store.sessions[sid]=dict(token=tokens['access_token'],subject=access['sub'],csrf=secrets.token_urlsafe(32),until=until)
                        return self.reply(302,'',cookie=owner.cookie(SESSION,sid,max(0,int(until-time.time()))),location='/')
                    except Exception:return self.reply(401,'Login could not be verified')
                if owner.configured and path!='/session':return self.reply(404,'Not found')
                if not session:return self.reply(401,'Sign in required')
                if path=='/session':return self.reply(200,dict(subject=session['subject'],csrf=session['csrf'],expiresAt=session['until']))
                if not owner.configured and re.fullmatch(r'/api/(account|accountuser)/(\d+)?',path):
                    try:status,data=api_request('GET',path[4:],session['token']);return self.reply(status,data)
                    except OSError:return self.reply(503,'Account API unavailable')
                return self.reply(404,'Not found')
        tls=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);tls.minimum_version=ssl.TLSVersion.TLSv1_2;tls.load_cert_chain(cert,key)
        self.server=BoundedTLSServer((listen_host,listen_port),Handler,tls)
    @staticmethod
    def switch_url(origin=ORIGIN,issuer=ISSUER,client_id=CLIENT):
        return issuer+'/protocol/openid-connect/logout?'+urllib.parse.urlencode(dict(client_id=client_id,post_logout_redirect_uri=origin+'/'))
    @staticmethod
    def cookie(name,value,age):return f'{name}={value}; Path=/; Max-Age={age}; Secure; HttpOnly; SameSite=Lax'
    def start(self):self.thread=threading.Thread(target=self.server.serve_forever,daemon=True);self.thread.start();return self
    @staticmethod
    def key_fingerprint(verifier):
        from cryptography.hazmat.primitives import serialization
        result=[]
        for kid,key in verifier.keys.items():
            if not isinstance(kid,str) or not kid or len(kid)>128 or key.key_size<2048:raise ValueError('Invalid signing key')
            result.append((kid,hashlib.sha256(key.public_bytes(serialization.Encoding.DER,serialization.PublicFormat.SubjectPublicKeyInfo)).hexdigest()))
        return tuple(sorted(result))
    def trust_ready(self):return not self.trust_failed and self.access.clock()-self.access.loaded<300
    def invalidate_trust(self):
        with self.store.lock:
            self.trust_failed=True;self.access.loaded=float('-inf');self.identity.loaded=float('-inf')
            self.store.sessions.clear();self.store.pending.clear()
    def refresh_trust(self,jwks):
        access=TokenVerifier(jwks,issuer=self.issuer,audience=self.audience)
        identity=TokenVerifier(jwks,issuer=self.issuer,audience=self.client_id)
        with self.store.lock:
            if self.trust_failed or self.key_fingerprint(access)!=self.approved_keys:
                self.invalidate_trust();raise ValueError('Signing key set changed; restart required')
            self.access,self.identity=access,identity
    def close(self):
        if self.closed:return
        self.closed=True
        if self.thread:self.server.shutdown()
        self.server.server_close()
        if self.thread:self.thread.join(timeout=5)
