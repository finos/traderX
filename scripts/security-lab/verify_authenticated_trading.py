"""Real cookie-authorized orders, scoped TLS pricing and service-authenticated settlement."""
import argparse
import asyncio
import hashlib
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
from browser_session import BrowserServer, ORIGIN, SESSION
from event_delivery import connect_broker
from identity_fixture import ISSUER, IMAGE, TokenVerifier
from jetstream_fixture import broker
import portability
from resource_operation import operation
from verify_bootstrap import database, fingerprint, require
from verify_browser_api import Browser, provider
from verify_execution_reservations import MIGRATION, SETTLEMENT
from verify_execution_events import EVENTS

ROOT=Path(__file__).resolve().parents[2]
CANCELLATION=ROOT/'specs/019-traderx-security-lab/system/sql/execution-cancellation.sql'
MATCHER_CLIENT='security-lab-matcher'
MATCHER_SUBJECT='lab-matcher-service'
TRADING_AUDIENCE='traderx-api'
EXECUTION_AUDIENCE='traderx-execution'
BROKER_PERMISSIONS={
    'matcher':{'publish':{'allow':['/accounts/62654/orders']},'subscribe':{'allow':['pricing.*']}},
    'pricing-fixture':{'publish':{'allow':['pricing.IBM']},'subscribe':{'deny':['>']}},
}


def audience(name):
    return {'name':name,'protocol':'openid-connect','protocolMapper':'oidc-audience-mapper',
        'config':{'included.custom.audience':name,'access.token.claim':'true','id.token.claim':'false'}}


def configure_realm(config, secret):
    # Distinct caller and execution audiences; never put the execution mapper on
    # the public browser client. Import a fixed service subject for exact checks.
    config['accessTokenLifespan']=45
    config['clients'][0]['protocolMappers'].append(audience(TRADING_AUDIENCE))
    config['clients'].append({'clientId':MATCHER_CLIENT,'protocol':'openid-connect',
        'publicClient':False,'secret':secret,'clientAuthenticatorType':'client-secret',
        'serviceAccountsEnabled':True,'standardFlowEnabled':False,'implicitFlowEnabled':False,
        'directAccessGrantsEnabled':False,'fullScopeAllowed':False,'defaultClientScopes':[],
        'optionalClientScopes':[],'redirectUris':[],'webOrigins':[],
        'attributes':{'access.token.lifespan':'45'},'protocolMappers':[audience(EXECUTION_AUDIENCE)]})
    config['users'].append({'id':MATCHER_SUBJECT,'username':'service-account-'+MATCHER_CLIENT,
        'enabled':True,'serviceAccountClientId':MATCHER_CLIENT,'realmRoles':[]})


def free_port():
    with socket.socket() as sock:sock.bind(('127.0.0.1',0));return sock.getsockname()[1]


def trusted_client(context):
    from browser_api import NoRedirect
    return urllib.request.build_opener(urllib.request.ProxyHandler({}),
        urllib.request.HTTPSHandler(context=context),NoRedirect())


def request(client,url,method='GET',body=None,headers=None):
    req=urllib.request.Request(url,method=method,data=body,headers=headers or {})
    try:response=client.open(req,timeout=10)
    except urllib.error.HTTPError as error:response=error
    with response:return response.code,response.read()


def service_token(context, secret, jwks):
    form=urllib.parse.urlencode({'grant_type':'client_credentials','client_id':MATCHER_CLIENT,'client_secret':secret}).encode()
    status,raw=request(trusted_client(context),ISSUER+'/protocol/openid-connect/token','POST',form,
        {'Content-Type':'application/x-www-form-urlencoded'})
    if status!=200:raise ValueError('Fixture service grant unavailable')
    token=json.loads(raw)['access_token']
    claims=TokenVerifier(jwks,audience=EXECUTION_AUDIENCE).verify(token)
    if claims['sub']!=MATCHER_SUBJECT:raise ValueError('Unexpected service subject')
    return token


def tls_files(private, mount, broker_ca):
    server_store=private/'server.p12';server_password=secrets.token_urlsafe(24)
    password_file=private/'store-password';password_file.write_text(server_password);password_file.chmod(0o600)
    subprocess.run(['openssl','pkcs12','-export','-in',str(mount/'cert.pem'),'-inkey',str(mount/'key.pem'),
        '-out',str(server_store),'-passout','file:'+str(password_file)],capture_output=True,check=True,timeout=30)
    truststore=private/'trust.p12'
    keytool=str(Path(portability.java()).with_name('keytool'))
    for name,certificate in [('provider-api',mount/'cert.pem'),('broker',broker_ca)]:
        # This store contains public certificates only; changeit is not a service credential.
        subprocess.run([keytool,'-importcert','-noprompt','-alias',name,'-file',str(certificate),
            '-keystore',str(truststore),'-storetype','PKCS12','-storepass','changeit'],
            capture_output=True,check=True,timeout=30)
    return server_store,server_password,truststore


class JavaService:
    def __init__(self,runtime,private,service,environment,context,truststore):
        target=runtime/'trading-security-build'/service
        report=json.loads((runtime/'evidence/trading-security-build.json').read_text())
        self.entry=next(item for item in report['services'] if item['service']==service)
        for name,digest in self.entry['generation']['inputs'].items():
            if hashlib.sha256((ROOT/name).read_bytes()).hexdigest()!=digest:raise ValueError('Trading input drift')
        jars=[path for path in (target/'build/libs').glob('*.jar') if not path.name.endswith('-plain.jar')]
        if len(jars)!=1 or hashlib.sha256(jars[0].read_bytes()).hexdigest()!=self.entry['jar_sha256']:
            raise ValueError('Unverified trading jar')
        self.port=free_port();self.origin=f'https://localhost:{self.port}'
        self.env=dict(os.environ,**environment,SERVER_ADDRESS='127.0.0.1',SERVER_PORT=str(self.port))
        self.args=[portability.java(),'-Xmx256m','-XX:MaxMetaspaceSize=192m',
            '-Djavax.net.ssl.trustStore='+str(truststore),'-Djavax.net.ssl.trustStorePassword=changeit',
            '-jar',str(jars[0]),'--server.port='+str(self.port)]
        self.client=trusted_client(context);self.log=private/(service+'.log');self.child=None

    def start(self):
        if self.child and self.child.poll() is None:raise ValueError('Service already running')
        with self.log.open('a') as output:
            self.log.chmod(0o600)
            self.child=subprocess.Popen(self.args,env=self.env,stdout=output,stderr=subprocess.STDOUT)
        deadline=time.monotonic()+90
        while time.monotonic()<deadline:
            if self.child.poll() is not None:raise RuntimeError('Trading service exited; private log withheld')
            try:
                if request(self.client,self.origin+'/actuator/health')[0]==200:return self
            except OSError:pass
            time.sleep(.5)
        raise RuntimeError('Trading service readiness timed out')

    def stop(self):
        if self.child and self.child.poll() is None:
            self.child.terminate()
            try:self.child.wait(timeout=20)
            except subprocess.TimeoutExpired:self.child.kill();self.child.wait(timeout=10)


async def price_tick(settings):
    connection=await connect_broker(settings['endpoint'],'pricing-fixture',settings['passwords']['pricing-fixture'],settings['ca'])
    try:
        await connection.publish('pricing.IBM',b'{"price":99.000}')
        await connection.flush(timeout=3)
    finally:await connection.close()


def wait_for(predicate,label,timeout=30):
    deadline=time.monotonic()+timeout
    while time.monotonic()<deadline:
        if predicate():return
        time.sleep(.25)
    raise AssertionError(label)


def campaign(runtime):
    if not __debug__:raise RuntimeError('Trading campaign requires assertions')
    checks=[]
    def check(name,condition):
        if not condition:raise AssertionError(name)
        checks.append(name);print(name+': passed',flush=True)
    reference=bootstrap_database.pinned_reference();identities=bootstrap_database.credentials()
    image=next(d for d in reference['items'] if d['kind']=='Deployment' and d['metadata']['name']=='database')['spec']['template']['spec']['containers'][0]['image']
    with tempfile.TemporaryDirectory(prefix='authenticated-trading-',dir=runtime) as temp:
        private=Path(temp);matcher_secret=secrets.token_urlsafe(32)
        with provider(runtime,private,configure=lambda config:configure_realm(config,matcher_secret)) as (mount,context,jwks,passwords):
            with database(runtime,image,persistent=True,loopback=True) as (sql,password,restart_db,pgport):
                def admin(query):return require(sql('traderx',password,query),'Trading SQL observation failed')
                admin(bootstrap_database.render(reference,identities))
                for migration in (MIGRATION,SETTLEMENT,CANCELLATION,EVENTS):admin(migration.read_text())
                initial_quantity=int(admin("SELECT COALESCE(sum(quantity),0) FROM positions WHERE accountid=62654 AND security='IBM';"))
                initial_trades=int(admin('SELECT count(*) FROM trades;'))
                with broker(runtime,extra_permissions=BROKER_PERMISSIONS) as settings:
                    stores=tls_files(private,mount,settings['ca'])
                    public=private/'public.pem'
                    keys=TokenVerifier(jwks).keys
                    if len(keys)!=1:raise ValueError('Expected one fixture signing key')
                    public.write_bytes(next(iter(keys.values())).public_bytes(serialization.Encoding.PEM,serialization.PublicFormat.SubjectPublicKeyInfo))
                    entitlements=private/'entitlements.txt';entitlements.write_text('lab-reader=read-only:22214\nlab-trader=trader:62654\nlab-operator=operator:\n')
                    service_secret=private/'matcher-secret';service_secret.write_text('deliberately-invalid-fixture-secret');service_secret.chmod(0o600)
                    broker_secret=private/'broker-secret';broker_secret.write_text(settings['passwords']['matcher']);broker_secret.chmod(0o600)
                    common=dict(DATABASE_PG_HOST='127.0.0.1',DATABASE_PG_PORT=str(pgport),DATABASE_NAME='traderx',
                        LAB_IDENTITY_ISSUER=ISSUER,LAB_IDENTITY_PUBLIC_KEY_FILE=str(public),
                        LAB_IDENTITY_KEY_NOT_AFTER=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime(time.time()+600)),
                        SERVER_SSL_ENABLED='true',SERVER_SSL_KEY_STORE='file:'+str(stores[0]),
                        SERVER_SSL_KEY_STORE_TYPE='PKCS12',SERVER_SSL_KEY_STORE_PASSWORD=stores[1],
                        SPRING_JPA_SHOW_SQL='false',LOGGING_LEVEL_ORG_HIBERNATE_SQL='OFF',SPRING_JPA_HIBERNATE_DDL_AUTO='none')
                    processor_identity=identities['trade-processor'];matcher_identity=identities['order-matcher']
                    processor=JavaService(runtime,private,'trade-processor',dict(common,
                        DATABASE_DBUSER=processor_identity['username'],DATABASE_DBPASS=processor_identity['password'],
                        LAB_IDENTITY_AUDIENCE=EXECUTION_AUDIENCE,LAB_EXECUTION_MATCHER_SUBJECT=MATCHER_SUBJECT),context,stores[2])
                    matcher=JavaService(runtime,private,'order-matcher',dict(common,
                        DATABASE_DBUSER=matcher_identity['username'],DATABASE_DBPASS=matcher_identity['password'],
                        LAB_IDENTITY_AUDIENCE=TRADING_AUDIENCE,LAB_IDENTITY_ENTITLEMENTS_FILE=str(entitlements),
                        LAB_EXECUTION_ENABLED='true',LAB_EXECUTION_ENDPOINT=processor.origin+'/internal/executions/',
                        LAB_EXECUTION_TOKEN_ENDPOINT=ISSUER+'/protocol/openid-connect/token',
                        LAB_EXECUTION_CLIENT_ID=MATCHER_CLIENT,LAB_EXECUTION_SECRET_FILE=str(service_secret),
                        NATS_ADDRESS=settings['endpoint'],LAB_BROKER_USERNAME='matcher',LAB_BROKER_SECRET_FILE=str(broker_secret),
                        ORDER_MATCHER_SEED_ENABLED='false',ORDER_MATCHER_TICK_MS='250'),context,stores[2])
                    server=None
                    try:
                        processor.start();matcher.start()
                        grant=service_token(context,matcher_secret,jwks)
                        check('live service grant has dedicated audience and exact matcher subject',bool(grant));del grant
                        server=BrowserServer(mount/'cert.pem',mount/'key.pem',context,jwks,
                            api_proxy=ApiProxy({'order-matcher':matcher.origin},context)).start()
                        browser=Browser(context)
                        def call(path,body=None,csrf=None):
                            headers={} if body is None else {'Origin':ORIGIN,'X-CSRF-Token':csrf or '', 'Content-Type':'application/json'}
                            return browser.request(ORIGIN+path,body,headers)
                        def login(name):
                            browser.login(name,passwords[name])
                            status,_,raw=call('/session');value=json.loads(raw)
                            if status!=200:raise ValueError('Trading browser session unavailable')
                            return value
                        def payload(account=62654,security='IBM',quantity=10,limit=100):
                            return json.dumps(dict(accountId=account,security=security,side='Buy',quantity=quantity,limitPrice=limit)).encode()
                        def create(session,**kwargs):
                            status,_,raw=call('/api/order-matcher/orders',payload(**kwargs),session['csrf'])
                            if status!=201:raise AssertionError('Authorized order create failed: HTTP '+str(status))
                            order=json.loads(raw)['orderId']
                            if not isinstance(order,str) or not __import__('re').fullmatch(r'ord-013-[0-9]+',order):raise ValueError('Unexpected order ID')
                            return order
                        baseline=fingerprint(sql,password)
                        check('anonymous browser order access denied',call('/api/order-matcher/orders')[0]==401)
                        check('direct matcher backend requires bearer',request(trusted_client(context),matcher.origin+'/orders')[0]==401)
                        for name in ('reader','operator'):
                            session=login(name)
                            if name=='operator':
                                # Fixture-owned server memory, never returned through the browser API.
                                sid=next(cookie.value for cookie in browser.jar if cookie.name==SESSION)
                                with server.store.lock:operator_token=server.store.sessions[sid]['token']
                            check(name+' cannot submit order',call('/api/order-matcher/orders',payload(account=22214 if name=='reader' else 62654),session['csrf'])[0]==403)
                            check(name+' denied order leaves business state unchanged',fingerprint(sql,password)==baseline)
                        session=login('trader')
                        check('trader cross-account order rejected',call('/api/order-matcher/orders',payload(account=22214),session['csrf'])[0]==403)
                        check('missing CSRF write rejected',call('/api/order-matcher/orders',payload(),csrf='')[0]==403)
                        check('all rejected writes preserve business state',fingerprint(sql,password)==baseline)
                        order=create(session)
                        check('accepted order records trusted user and issuer',admin(f"SELECT acceptedsubject||'|'||acceptedissuer FROM orderbook WHERE orderid='{order}';")=='lab-trader|'+ISSUER)
                        asyncio.run(price_tick(settings))
                        wait_for(lambda:admin(f"SELECT count(*) FROM lab_execution.reservations WHERE order_id='{order}';")=='1','Price tick did not reserve execution')
                        check('actual pricing subscriber creates one durable reservation',True)
                        def observed_failure():
                            code,raw=request(trusted_client(context),matcher.origin+'/health',headers={'Authorization':'Bearer '+operator_token})
                            if code!=200:raise AssertionError('Operator matcher observation unavailable')
                            return json.loads(raw)['matcher']['tradeSubmitFailures']>=1
                        wait_for(observed_failure,'Matcher did not observe failed service handoff')
                        check('invalid service credential cannot settle',admin('SELECT count(*) FROM lab_execution.receipts;')=='0' and int(admin('SELECT count(*) FROM trades;'))==initial_trades)
                        check('ordinary user audience cannot invoke processor',request(trusted_client(context),processor.origin+'/internal/executions/'+str(uuid.uuid4()),'POST',headers={'Authorization':'Bearer '+operator_token})[0]==401)
                        service_secret.write_text(matcher_secret)
                        wait_for(lambda:admin(f"SELECT status FROM orderbook WHERE orderid='{order}';")=='FILLED','Live credential refresh did not settle order')
                        check('actual matcher token client and HTTPS processor settle accepted order',admin('SELECT count(*) FROM lab_execution.receipts;')=='1')
                        check('first independent trade and position effects',int(admin('SELECT count(*) FROM trades;'))==initial_trades+1 and int(admin("SELECT quantity FROM positions WHERE accountid=62654 AND security='IBM';"))==initial_quantity+10)
                        check('settlement commits two account-scoped outbox events',admin("SELECT count(*) FROM lab_execution.events WHERE topic IN ('/accounts/62654/trades','/accounts/62654/positions');")=='2')
                        stable=fingerprint(sql,password);asyncio.run(price_tick(settings));time.sleep(1)
                        check('repeated price tick cannot book filled order again',fingerprint(sql,password)==stable)
                        session=login('trader');cancel=create(session,security='MSFT',limit=1,quantity=3)
                        reader=login('reader')
                        check('reader cannot cancel another account order',call('/api/order-matcher/orders/'+cancel+'/cancel',b'',reader['csrf'])[0]==403)
                        session=login('trader')
                        check('authorized stored-account cancellation succeeds',call('/api/order-matcher/orders/'+cancel+'/cancel',b'',session['csrf'])[0]==200 and admin(f"SELECT status||'|'||remainingquantity FROM orderbook WHERE orderid='{cancel}';")=='CANCELED|0')
                        processor.stop()
                        recovery=create(session,quantity=4)
                        wait_for(lambda:admin(f"SELECT count(*) FROM lab_execution.reservations WHERE order_id='{recovery}';")=='1','Unavailable processor did not retain reservation')
                        execution=str(uuid.UUID(admin(f"SELECT execution_id FROM lab_execution.reservations WHERE order_id='{recovery}';")))
                        check('unavailable processor retains pending identity without effects',admin('SELECT count(*) FROM lab_execution.receipts;')=='1')
                        check('initiating browser logout succeeds',call('/logout',b'',session['csrf'])[0]==200)
                        matcher.stop();matcher.start()
                        check('matcher restart preserves pending execution identity',admin(f"SELECT execution_id FROM lab_execution.reservations WHERE order_id='{recovery}';")==execution)
                        wait_for(lambda:time.time()>session['expiresAt']+1,'Initiating access-token expiry deadline',timeout=60)
                        check('logged-out expired browser cannot read orders',call('/api/order-matcher/orders')[0]==401)
                        processor.start()
                        wait_for(lambda:admin(f"SELECT status FROM orderbook WHERE orderid='{recovery}';")=='FILLED','Restarted matcher/processor did not settle pending execution')
                        check('accepted authority executes after browser expiry and process restart',admin(f"SELECT count(*) FROM lab_execution.receipts WHERE execution_id='{execution}';")=='1')
                        check('retry reuses original execution without overbooking',admin(f"SELECT count(*) FROM lab_execution.reservations WHERE order_id='{recovery}';")=='1' and admin('SELECT count(*) FROM lab_execution.receipts;')=='2')
                        check('recovered independent trade position and event effects',int(admin('SELECT count(*) FROM trades;'))==initial_trades+2 and int(admin("SELECT quantity FROM positions WHERE accountid=62654 AND security='IBM';"))==initial_quantity+14 and admin('SELECT count(*) FROM lab_execution.events;')=='4')
                        session=login('trader')
                        status,_,raw=call('/api/order-matcher/orders/'+recovery)
                        check('fresh browser session sees settled order',status==200 and json.loads(raw)['status']=='FILLED')
                        check('retired anonymous processor booking path denied',request(trusted_client(context),processor.origin+'/tradeservice/order','POST',b'{}',{'Content-Type':'application/json'})[0] in (401,403))
                        for service in (matcher,processor):
                            text=service.log.read_text()
                            check(service.entry['service']+' log omits configured credentials',all(value not in text for value in (matcher_secret,settings['passwords']['matcher'],matcher_identity['password'],processor_identity['password'],stores[1])))
                    finally:
                        if server:server.close()
                        matcher.stop();processor.stop()
                    jar_hashes={service.entry['service']:service.entry['jar_sha256'] for service in (matcher,processor)}
                    broker_image=settings['image']
    return dict(status='passed',scope='Real authenticated trading candidate; not deployed cumulative State019',
        jars=jar_hashes,provider_image=IMAGE,database_image=image,broker_image=broker_image,checks=checks,
        migrations={str(path.relative_to(ROOT)):hashlib.sha256(path.read_bytes()).hexdigest() for path in (MIGRATION,SETTLEMENT,CANCELLATION,EVENTS)},
        limitations=['Synthetic scoped price producer, not the complete C3 market-data application',
            'Settlement outbox effects are observed; durable delivery/browser notification is a separate cumulative gate',
            'PostgreSQL uses explicit loopback transport; gateway/WAF/network/admission integration is not established',
            'Logout ends only the browser session; accepted order authority intentionally remains subject to the loaded entitlement map',
            'No live entitlement-policy reload, issuer rotation, production TLS provisioning or Kubernetes cutover claim'])


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-dir',required=True,type=Path);parser.add_argument('--output',required=True,type=Path)
    args=parser.parse_args();os.umask(0o077)
    if args.output.exists():raise ValueError('Evidence already exists')
    with operation(args.runtime_dir,'fixture'):result=campaign(args.runtime_dir)
    with args.output.open('x') as output:json.dump(result,output,indent=2);output.write('\n')
    print(json.dumps(result,sort_keys=True))


if __name__=='__main__':main()
