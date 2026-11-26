"""Hosted real Angular/Keycloak/trading/delivery journey; no deployed-state claim."""
import argparse
import asyncio
import hashlib
import json
import os
from pathlib import Path
import secrets
import shutil
import tempfile
import time
import uuid

from cryptography.hazmat.primitives import serialization
import bootstrap_database
from authenticated_delivery import deliver
from browser_api import ApiProxy
from browser_assets import PublicAssets
from browser_broker import BrokerEvents
from browser_journey_fixture import AccountService, MarketPeers, chromium_trust, driver_checks, run_driver, verified_frontend
from browser_session import BrowserServer, ORIGIN
from identity_fixture import IMAGE, ISSUER, TokenVerifier
from jetstream_fixture import broker
import portability
from resource_operation import operation
from verify_authenticated_trading import (ROOT, BROKER_PERMISSIONS, CANCELLATION, CONSUMER, EVENTS, MIGRATION,
    SETTLEMENT, MATCHER_CLIENT, MATCHER_SUBJECT, TRADING_AUDIENCE, EXECUTION_AUDIENCE,
    JavaService, configure_realm, price_tick, tls_files, wait_for)
from verify_bootstrap import database, fingerprint, require
from verify_browser_api import provider

DRIVER=ROOT/'scripts/security-lab/browser_journey.mjs'


def campaign(runtime):
    if not __debug__ or not portability.isolated_linux():raise RuntimeError('Journey requires isolated hosted Linux with assertions')
    frontend,manifest=verified_frontend(runtime)
    assets=PublicAssets(frontend/'dist/main-application/browser')
    node=shutil.which('node');chrome=shutil.which('google-chrome') or shutil.which('chromium')
    if not node or not chrome or not DRIVER.is_file():raise ValueError('Hosted browser tools required')
    expected_checks=driver_checks(node,DRIVER)
    checks=[]
    def check(name,condition):
        if not condition:raise AssertionError(name)
        checks.append(name);print(name+': passed',flush=True)
    reference=bootstrap_database.pinned_reference();identities=bootstrap_database.credentials()
    image=next(d for d in reference['items'] if d['kind']=='Deployment' and d['metadata']['name']=='database')['spec']['template']['spec']['containers'][0]['image']
    with tempfile.TemporaryDirectory(prefix='browser-journey-',dir=runtime) as temp:
        private=Path(temp);matcher_secret=secrets.token_urlsafe(32)
        def realm(config):
            configure_realm(config,matcher_secret)
            # The explicit expiry/restart case remains in the independent trading campaign.
            config['accessTokenLifespan']=300
        with provider(runtime,private,configure=realm) as (mount,context,jwks,passwords):
            with database(runtime,image,persistent=True,loopback=True) as (sql,password,_,pgport):
                def admin(query):return require(sql('traderx',password,query),'Journey SQL observation failed')
                admin(bootstrap_database.render(reference,identities))
                for path in (MIGRATION,SETTLEMENT,CANCELLATION,EVENTS,CONSUMER):admin(path.read_text())
                worker_passwords={name:secrets.token_hex(24) for name in ('event_publisher','event_consumer_b')}
                for name,secret in worker_passwords.items():
                    role='lab_event_publisher' if name=='event_publisher' else 'lab_event_consumer'
                    admin(f"CREATE ROLE {name} LOGIN PASSWORD '{secret}' IN ROLE {role}; GRANT CONNECT ON DATABASE traderx TO {name};")
                admin("INSERT INTO lab_execution.consumer_accounts VALUES ('event_consumer_b',62654);")
                initial_quantity=int(admin("SELECT COALESCE(sum(quantity),0) FROM positions WHERE accountid=62654 AND security='IBM';"))
                initial_trades=int(admin('SELECT count(*) FROM trades;'))
                initial_orders=int(admin('SELECT count(*) FROM orderbook;'))
                with broker(runtime,extra_permissions=BROKER_PERMISSIONS) as settings:
                    stores=tls_files(private,mount,settings['ca'])
                    keys=TokenVerifier(jwks).keys
                    if len(keys)!=1:raise ValueError('Expected one fixture signing key')
                    public=private/'public.pem'
                    public.write_bytes(next(iter(keys.values())).public_bytes(serialization.Encoding.PEM,serialization.PublicFormat.SubjectPublicKeyInfo))
                    grants=private/'entitlements.txt';grants.write_text('lab-reader=read-only:22214\nlab-trader=trader:62654\nlab-operator=operator:\n')
                    service_secret=private/'matcher-secret';service_secret.write_text(matcher_secret);service_secret.chmod(0o600)
                    broker_secret=private/'broker-secret';broker_secret.write_text(settings['passwords']['matcher']);broker_secret.chmod(0o600)
                    common=dict(DATABASE_PG_HOST='127.0.0.1',DATABASE_PG_PORT=str(pgport),DATABASE_NAME='traderx',
                        LAB_IDENTITY_ISSUER=ISSUER,LAB_IDENTITY_PUBLIC_KEY_FILE=str(public),LAB_IDENTITY_ENTITLEMENTS_FILE=str(grants),
                        LAB_IDENTITY_KEY_NOT_AFTER=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime(time.time()+900)),
                        SERVER_SSL_ENABLED='true',SERVER_SSL_KEY_STORE='file:'+str(stores[0]),
                        SERVER_SSL_KEY_STORE_TYPE='PKCS12',SERVER_SSL_KEY_STORE_PASSWORD=stores[1],
                        SPRING_JPA_SHOW_SQL='false',LOGGING_LEVEL_ORG_HIBERNATE_SQL='OFF',SPRING_JPA_HIBERNATE_DDL_AUTO='none')
                    def environment(service,audience=TRADING_AUDIENCE):
                        identity=identities[service]
                        return dict(common,DATABASE_DBUSER=identity['username'],DATABASE_DBPASS=identity['password'],LAB_IDENTITY_AUDIENCE=audience)
                    processor=JavaService(runtime,private,'trade-processor',dict(environment('trade-processor',EXECUTION_AUDIENCE),LAB_EXECUTION_MATCHER_SUBJECT=MATCHER_SUBJECT),context,stores[2])
                    matcher=JavaService(runtime,private,'order-matcher',dict(environment('order-matcher'),
                        LAB_EXECUTION_ENABLED='true',LAB_EXECUTION_ENDPOINT=processor.origin+'/internal/executions/',
                        LAB_EXECUTION_TOKEN_ENDPOINT=ISSUER+'/protocol/openid-connect/token',
                        LAB_EXECUTION_CLIENT_ID=MATCHER_CLIENT,LAB_EXECUTION_SECRET_FILE=str(service_secret),
                        NATS_ADDRESS=settings['endpoint'],LAB_BROKER_USERNAME='matcher',LAB_BROKER_SECRET_FILE=str(broker_secret),
                        ORDER_MATCHER_SEED_ENABLED='false',ORDER_MATCHER_TICK_MS='250'),context,stores[2])
                    position=JavaService(runtime,private,'position-service',environment('position-service'),context,stores[2])
                    account=AccountService(runtime,private,environment('account-service'),context,stores[2])
                    services=(processor,matcher,position,account);server=None;notifications=None;market=None
                    try:
                        for service in services:service.start()
                        market=MarketPeers(mount/'cert.pem',mount/'key.pem',jwks).start()
                        notifications=BrokerEvents({'lab-reader':{22214},'lab-trader':{62654},'lab-operator':set()},
                            {number:{'user':name,'password':settings['passwords'][name]} for number,name in ((22214,'browser-reader'),(62654,'browser-trader'))},settings['endpoint'],settings['ca']).start()
                        wait_for(notifications.ready,'Journey broker subscriptions unavailable')
                        backends={'order-matcher':matcher.origin,'position-service':position.origin,'account-service':account.origin,
                            'reference-data':market.origin,'price-publisher':market.origin}
                        server=BrowserServer(mount/'cert.pem',mount/'key.pem',context,jwks,
                            api_proxy=ApiProxy(backends,context),broker_events=notifications,assets=assets,configured=True,audience=TRADING_AUDIENCE).start()
                        profile=private/'chromium-profile';profile.mkdir(mode=0o700)
                        config=dict(origin=ORIGIN,issuer=ISSUER,frontendRoot=str(frontend),executablePath=chrome,profileDir=str(profile),
                            users={name:dict(username=name,password=passwords[name]) for name in ('trader','reader')},
                            accounts={'trader':62654,'reader':22214},security='IBM',quantity=2,limitPrice=100,
                            expectedPositionQuantity=initial_quantity+2,expectedTradePrice=99)
                        config_path=private/'driver.json';config_path.write_text(json.dumps(config));config_path.chmod(0o600)
                        execution=None;settled=None
                        async def stage(name,order):
                            nonlocal execution,settled
                            if name=='ready_for_price':
                                check('Angular order records accepted trader identity and explicit terms',
                                    admin(f"SELECT acceptedsubject||'|'||acceptedissuer||'|'||accountid||'|'||security||'|'||quantity||'|'||status FROM orderbook WHERE orderid='{order}';")=='lab-trader|'+ISSUER+'|62654|IBM|2|NEW')
                                check('no settlement before explicit synthetic price stimulus',admin('SELECT count(*) FROM lab_execution.receipts;')=='0')
                                await price_tick(settings)
                                await asyncio.to_thread(wait_for,lambda:admin(f"SELECT status FROM orderbook WHERE orderid='{order}';")=='FILLED','Browser order did not settle')
                                execution=str(uuid.UUID(admin(f"SELECT execution_id FROM lab_execution.reservations WHERE order_id='{order}';")))
                                check('UI order settles once through real service-authenticated processor',
                                    admin(f"SELECT count(*) FROM lab_execution.receipts WHERE execution_id='{execution}';")=='1' and
                                    int(admin('SELECT count(*) FROM trades;'))==initial_trades+1 and
                                    int(admin("SELECT quantity FROM positions WHERE accountid=62654 AND security='IBM';"))==initial_quantity+2)
                                check('UI settlement commits exactly two scoped outbox rows',admin("SELECT count(*) FROM lab_execution.events WHERE topic IN ('/accounts/62654/trades','/accounts/62654/positions');")=='2')
                                settled=fingerprint(sql,password)
                            elif name=='ready_for_delivery':
                                if execution is None:raise AssertionError('Delivery before settlement')
                                await deliver(private,settings,pgport,worker_passwords,admin,check,expected_events=2)
                                check('event delivery never rebooks browser trade',fingerprint(sql,password)==settled)
                        with chromium_trust(mount/'cert.pem'):
                            result=asyncio.run(run_driver(node,DRIVER,config_path,private,stage,expected_checks))
                        canceled=result['cancelOrderId']
                        check('actual UI cancellation persisted without another settlement',
                            admin(f"SELECT status||'|'||remainingquantity FROM orderbook WHERE orderid='{canceled}';")=='CANCELED|0' and
                            int(admin('SELECT count(*) FROM orderbook;'))==initial_orders+2 and
                            admin('SELECT count(*) FROM lab_execution.receipts;')=='1' and
                            int(admin('SELECT count(*) FROM trades;'))==initial_trades+1)
                        check('read-only cross-account and CSRF attempts leave final position unchanged',
                            int(admin("SELECT quantity FROM positions WHERE accountid=62654 AND security='IBM';"))==initial_quantity+2)
                        private_values=[matcher_secret,stores[1],*passwords.values(),*settings['passwords'].values(),
                            *worker_passwords.values(),*[value['password'] for value in identities.values()]]
                        logs=''.join(path.read_text() for path in private.glob('*.log'))
                        check('owned browser worker and Java logs omit configured credentials',all(secret not in logs for secret in private_values))
                        jar_hashes={service.entry['service']:service.entry['jar_sha256'] for service in services}
                        asset_hashes={path:hashlib.sha256(content[0]).hexdigest() for path,content in assets.files.items()}
                        broker_image=settings['image']
                    finally:
                        if server:server.close()
                        if notifications:notifications.close()
                        if market:market.close()
                        for service in reversed(services):service.stop()
    return dict(status='passed',scope='Real hosted Angular browser and authenticated service journey; not Kubernetes acceptance',
        checks=checks,browser_checks=result['checks'],order_id=result['orderId'],cancel_order_id=result['cancelOrderId'],execution_id=execution,
        jars=jar_hashes,assets=asset_hashes,frontend_inputs=manifest['inputs'],provider_image=IMAGE,database_image=image,broker_image=broker_image,
        source_sha256={str(path.relative_to(ROOT)):hashlib.sha256(path.read_bytes()).hexdigest() for path in
            (Path(__file__).resolve(),DRIVER,ROOT/'scripts/security-lab/browser_journey_fixture.py',ROOT/'scripts/security-lab/authenticated_delivery.py')},
        limitations=['Synthetic reference symbols, display quotes and scoped market tick; real account/order/trade/position APIs.',
            'PostgreSQL uses explicit loopback fixture transport; HTTPS and broker TLS use an ephemeral localhost CA.',
            'Chromium uses a dedicated temporary profile and hosted-only NSS certificate; no local workstation trust changes.',
            'No cumulative Kubernetes, ingress/WAF, network-policy or image-admission claim.'])


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--runtime-dir',required=True,type=Path);parser.add_argument('--output',required=True,type=Path)
    args=parser.parse_args();os.umask(0o077)
    if args.output.exists():raise ValueError('Evidence already exists')
    with operation(args.runtime_dir,'fixture'):result=campaign(args.runtime_dir.resolve())
    with args.output.open('x') as output:json.dump(result,output,indent=2);output.write('\n')
    print('Real Angular browser journey passed; deployed-state acceptance remains separate.')


if __name__=='__main__':main()
