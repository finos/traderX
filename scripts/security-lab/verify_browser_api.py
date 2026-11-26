"""Real TLS Keycloak -> opaque browser session -> scoped Spring reads -> PostgreSQL."""
import argparse
from contextlib import contextmanager
import hashlib
import http.cookiejar
import json
import os
from pathlib import Path
import secrets
import socket
import ssl
import subprocess
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

from cryptography.hazmat.primitives import serialization
import bootstrap_database
from browser_api import ApiProxy
from browser_session import BrowserServer, CALLBACK, ORIGIN, SESSION
from identity_fixture import IMAGE, BASE, ISSUER, AUDIENCE, SUBJECTS, TokenVerifier, realm
import portability
from resource_operation import operation
from verify_bootstrap import command, database, fingerprint, require
from verify_identity import LoginForm, NoRedirect


@contextmanager
def provider(runtime, private, configure=None):
    """One owned provider, native platform, no inherited local-lab lifecycle."""
    docker=portability.docker(runtime);run_id=uuid.uuid4().hex
    name='traderx-browser-identity-'+run_id[:12];label='traderx.security-lab.browser='+run_id
    mount=private/'provider';mount.mkdir();mount.chmod(0o755)
    passwords={name:secrets.token_urlsafe(32) for name in SUBJECTS}
    config=realm(passwords);config['clients'][0]['redirectUris']=[CALLBACK]
    if configure is not None:configure(config)
    (mount/'realm.json').write_text(json.dumps(config))
    subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-nodes',
        '-keyout',str(mount/'key.pem'),'-out',str(mount/'cert.pem'),'-days','1',
        '-subj','/CN=localhost','-addext','subjectAltName=DNS:localhost,IP:127.0.0.1'],
        capture_output=True,check=True,timeout=30)
    for path in mount.iterdir():path.chmod(0o644)
    context=ssl.create_default_context(cafile=str(mount/'cert.pem'))
    opener=urllib.request.build_opener(urllib.request.ProxyHandler({}),urllib.request.HTTPSHandler(context=context),NoRedirect())
    def get(path):
        with opener.open(ISSUER+path,timeout=10) as response:return json.load(response)
    try:
        if subprocess.run(docker+['image','inspect',IMAGE],capture_output=True,timeout=30).returncode:
            command(docker+['pull',IMAGE],timeout=300)
        container=command(docker+['create','--name',name,'--label',label,'--restart','no',
            '--user','1000:1000','--cap-drop=ALL','--security-opt=no-new-privileges',
            '--memory','640m','--memory-swap','640m','--cpus','1','--pids-limit','256',
            '--log-driver','local','--log-opt','max-size=5m','--log-opt','max-file=2',
            '-e','JAVA_OPTS_KC_HEAP=-Xms64m -Xmx256m',
            '--mount',f'type=bind,src={mount},dst=/lab,readonly',
            '--mount',f'type=bind,src={mount}/realm.json,dst=/opt/keycloak/data/import/realm.json,readonly',
            '-p','127.0.0.1:18446:8443',IMAGE,'start-dev','--import-realm',
            '--hostname='+BASE,'--http-enabled=false',
            '--https-certificate-file=/lab/cert.pem','--https-certificate-key-file=/lab/key.pem'])
        command(docker+['start',container])
        deadline=time.monotonic()+150
        while True:
            try:
                discovery=get('/.well-known/openid-configuration')
                if discovery['issuer']!=ISSUER:raise ValueError('Issuer mismatch')
                break
            except (OSError,urllib.error.URLError):
                if time.monotonic()>deadline:raise RuntimeError('Browser provider readiness timed out') from None
                time.sleep(.5)
        jwks=get('/protocol/openid-connect/certs')
        yield mount,context,jwks,passwords
    finally:
        found=command(docker+['ps','-aq','--filter','name=^/'+name+'$','--filter','label='+label]).split()
        if len(found)>1:raise RuntimeError('Ambiguous provider ownership')
        if found:command(docker+['rm','-f',found[0]])


@contextmanager
def position_api(runtime, private, jwks, credentials, pgport):
    target=runtime/'position-service'
    manifest=json.loads((target/'security-generation.json').read_text())
    root=Path(__file__).resolve().parents[2]
    for name,digest in manifest['inputs'].items():
        if hashlib.sha256((root/name).read_bytes()).hexdigest()!=digest:raise ValueError('Read API input drift')
    for name,digest in manifest['files'].items():
        if hashlib.sha256((target/name).read_bytes()).hexdigest()!=digest:raise ValueError('Read API generated source drift')
    jars=[path for path in (target/'build/libs').glob('*.jar') if not path.name.endswith('-plain.jar')]
    if len(jars)!=1:raise ValueError('Expected one position candidate jar')
    keys=TokenVerifier(jwks).keys
    if len(keys)!=1:raise ValueError('Fixture requires one signing key')
    public=private/'public.pem'
    public.write_bytes(next(iter(keys.values())).public_bytes(serialization.Encoding.PEM,serialization.PublicFormat.SubjectPublicKeyInfo))
    entitlements=private/'entitlements.txt'
    entitlements.write_text('lab-reader=read-only:22214\nlab-trader=trader:62654\nlab-operator=operator:\n')
    with socket.socket() as probe:probe.bind(('127.0.0.1',0));port=probe.getsockname()[1]
    env=dict(os.environ,SERVER_ADDRESS='127.0.0.1',POSITION_SERVICE_PORT=str(port),
        DATABASE_PG_HOST='127.0.0.1',DATABASE_PG_PORT=str(pgport),DATABASE_NAME='traderx',
        DATABASE_DBUSER=credentials['username'],DATABASE_DBPASS=credentials['password'],
        LAB_IDENTITY_ISSUER=ISSUER,LAB_IDENTITY_AUDIENCE=AUDIENCE,
        LAB_IDENTITY_PUBLIC_KEY_FILE=str(public),LAB_IDENTITY_ENTITLEMENTS_FILE=str(entitlements),
        LAB_IDENTITY_KEY_NOT_AFTER=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime(time.time()+300)),
        SPRING_JPA_SHOW_SQL='false',LOGGING_LEVEL_ORG_HIBERNATE_SQL='OFF')
    with (private/'position.log').open('w') as output:
        child=subprocess.Popen([portability.java(),'-Xmx256m','-XX:MaxMetaspaceSize=192m','-jar',str(jars[0])],
            env=env,stdout=output,stderr=subprocess.STDOUT)
    origin=f'http://127.0.0.1:{port}'
    opener=urllib.request.build_opener(urllib.request.ProxyHandler({}),NoRedirect())
    try:
        deadline=time.monotonic()+90
        while True:
            if child.poll() is not None:raise RuntimeError('Read API exited; private log withheld')
            try:
                with opener.open(origin+'/actuator/health',timeout=2) as response:
                    if response.status==200:break
            except OSError:pass
            if time.monotonic()>deadline:raise RuntimeError('Read API readiness timed out')
            time.sleep(.5)
        yield origin,hashlib.sha256(jars[0].read_bytes()).hexdigest()
    finally:
        if child.poll() is None:
            child.terminate()
            try:child.wait(timeout=15)
            except subprocess.TimeoutExpired:child.kill();child.wait(timeout=10)


class Browser:
    def __init__(self,context):
        self.jar=http.cookiejar.CookieJar()
        self.client=urllib.request.build_opener(urllib.request.ProxyHandler({}),
            urllib.request.HTTPSHandler(context=context),urllib.request.HTTPCookieProcessor(self.jar),NoRedirect())

    def request(self,url,body=None,headers=None):
        parsed=urllib.parse.urlsplit(url)
        if parsed.scheme!='https' or parsed.netloc not in ('localhost:18446','localhost:18447'):
            raise ValueError('Request outside fixture origins')
        req=urllib.request.Request(url,data=body,headers=headers or {})
        try:response=self.client.open(req,timeout=15)
        except urllib.error.HTTPError as error:response=error
        with response:return response.code,dict(response.headers),response.read()

    def login(self,name,password):
        self.jar.clear()
        status,headers,_=self.request(ORIGIN+'/login')
        if status!=302 or not headers.get('Location','').startswith(ISSUER+'/protocol/openid-connect/auth?'):
            raise ValueError('Login redirect mismatch')
        status,_,html=self.request(headers['Location']);form=LoginForm(html.decode())
        if status!=200 or not form.action:raise ValueError('Provider login form missing')
        status,headers,_=self.request(form.action,urllib.parse.urlencode(dict(username=name,password=password,credentialId='')).encode())
        callback=headers.get('Location','')
        if status!=302 or not callback.startswith(CALLBACK+'?'):raise ValueError('Provider callback mismatch')
        status,headers,_=self.request(callback)
        if status!=302:raise ValueError('Browser callback rejected')
        flags=headers.get('Set-Cookie','')
        if not all(x in flags for x in (SESSION+'=','Secure','HttpOnly','SameSite=Lax','Path=/')) or 'Domain=' in flags:
            raise ValueError('Unsafe browser cookie')
        return callback


def campaign(runtime):
    if not __debug__:raise RuntimeError('Browser campaign requires assertions')
    checks=[]
    def check(name,condition):
        if not condition:raise AssertionError(name)
        checks.append(name);print(name+': passed',flush=True)
    reference=bootstrap_database.pinned_reference();identities=bootstrap_database.credentials()
    image=next(d for d in reference['items'] if d['kind']=='Deployment' and d['metadata']['name']=='database')['spec']['template']['spec']['containers'][0]['image']
    with tempfile.TemporaryDirectory(prefix='browser-api-',dir=runtime) as temp:
        private=Path(temp)
        with provider(runtime,private) as (mount,context,jwks,passwords):
            with database(runtime,image,loopback=True) as (sql,password,restart,pgport):
                require(sql('traderx',password,bootstrap_database.render(reference,identities)),'Browser database initialization failed')
                before=fingerprint(sql,password)
                with position_api(runtime,private,jwks,identities['position-service'],pgport) as (origin,jar_hash):
                    proxy=ApiProxy({'position-service':origin},loopback_fixture=True)
                    server=BrowserServer(mount/'cert.pem',mount/'key.pem',context,jwks,api_proxy=proxy).start()
                    try:
                        browser=Browser(context)
                        def call(path,body=None,headers=None):return browser.request(ORIGIN+path,body,headers)
                        check('anonymous cookie API denied',call('/api/position-service/positions/')[0]==401)
                        check('unsolicited callback denied',call('/callback?state=wrong&code=wrong')[0]==400)
                        opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
                        try:opener.open(origin+'/positions/',timeout=10);direct_status=200
                        except urllib.error.HTTPError as error:direct_status=error.code;error.close()
                        check('direct backend requires bearer',direct_status==401)
                        for name,allowed in (('reader',{22214}),('trader',{62654}),('operator',set())):
                            callback=browser.login(name,passwords[name])
                            check(name+' real PKCE callback and secure cookie',True)
                            check(name+' callback replay denied',call(callback.removeprefix(ORIGIN))[0]==400)
                            status,_,raw=call('/session');session=json.loads(raw)
                            check(name+' identity without bearer exposure',status==200 and set(session)=={'subject','csrf','expiresAt'} and session['subject']==SUBJECTS[name] and session['expiresAt']>time.time())
                            for kind in ('positions','trades'):
                                status,_,raw=call('/api/position-service/'+kind+'/');rows=json.loads(raw)
                                expected=int(require(sql('traderx',password,'SELECT count(*) FROM '+kind+(' WHERE accountid='+str(next(iter(allowed))) if allowed else ' WHERE false')+';'),'Count expected scoped rows'))
                                check(name+' '+kind+' scoped SQL snapshot',status==200 and isinstance(rows,list) and len(rows)==expected and all(row.get('accountId') in allowed for row in rows))
                                other=62654 if name=='reader' else 22214
                                check(name+' '+kind+' cross-account denied',call('/api/position-service/'+kind+'/'+str(other))[0]==403)
                            headers={'Origin':ORIGIN,'X-CSRF-Token':session['csrf'],'Content-Type':'application/json'}
                            check(name+' mutation missing CSRF denied',call('/api/order-matcher/orders',b'{}',{'Origin':ORIGIN,'Content-Type':'application/json'})[0]==403)
                            check(name+' cross-origin mutation denied',call('/api/order-matcher/orders',b'{}',dict(headers,Origin='https://untrusted.invalid'))[0]==403)
                            check(name+' duplicate account keys denied',call('/api/order-matcher/orders',b'{"accountId":1,"accountId":2}',headers)[0]==400)
                            check(name+' unconfigured mutation backend fails closed',call('/api/order-matcher/orders',b'{}',headers)[0]==503)
                            check(name+' operator proxy route unavailable',call('/api/position-service/actuator/health')[0]==404)
                            check(name+' all reads and rejected writes leave business tables unchanged',fingerprint(sql,password)==before)
                            old=next(c.value for c in browser.jar if c.name==SESSION)
                            check(name+' logout ends session',call('/logout',b'',headers)[0]==200)
                            check(name+' retired cookie cannot read',call('/api/position-service/positions/',headers={'Cookie':SESSION+'='+old})[0]==401)
                        browser.login('reader',passwords['reader'])
                        with server.store.lock:
                            for session in server.store.sessions.values():session['until']=0
                        check('expired browser session cannot read',call('/api/position-service/positions/')[0]==401)
                        browser.login('reader',passwords['reader'])
                        server.access.loaded-=301
                        check('expired signing-key snapshot invalidates browser session',call('/api/position-service/positions/')[0]==401)
                        check('final business state unchanged',fingerprint(sql,password)==before)
                    finally:server.close()
    return dict(status='passed',scope='Live provider/session/read API candidate; no deployed cutover',
        provider_image=IMAGE,read_api_jar_sha256=jar_hash,database_image=image,checks=checks,
        limitations=['HTTPS verified at provider/browser; API and PostgreSQL use explicit loopback fixture transport',
            'Shared fixture account API audience; deployment audience configuration remains a separate gate',
            'No Angular navigation, accepted order write, broker credential issuance or cumulative trading claim',
            'No provider rotation, refresh or global logout; finite key snapshot and local session logout only'])


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-dir',required=True,type=Path);parser.add_argument('--output',required=True,type=Path)
    args=parser.parse_args();os.umask(0o077)
    if args.output.exists():raise ValueError('Evidence already exists')
    with operation(args.runtime_dir,'fixture'):result=campaign(args.runtime_dir)
    with args.output.open('x') as output:json.dump(result,output,indent=2);output.write('\n')
    print(json.dumps(result,sort_keys=True))


if __name__=='__main__':main()
