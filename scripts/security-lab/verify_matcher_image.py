"""Actual matcher/processor images over verified TLS and synthetic scoped peers."""
import argparse
import copy
import datetime
import hashlib
import http.client
import json
import os
from pathlib import Path
import re
import secrets
import ssl
import tempfile
import time
import uuid

import jwt
import portability
import verify_runtime_images as images
from java_image_fixture import JavaImage, KEYS, certificate_material, private_java_probe, verified_image
from verify_bootstrap import fingerprint
from verify_execution_reservations import MIGRATION, SETTLEMENT
from verify_execution_events import EVENTS
from verify_processor_image import bounded_runtime, outbox_matches, snapshot
from verify_worker_images import peer_diagnostic
from worker_image_fixture import FixtureFailure

ROOT=Path(__file__).resolve().parents[2]
CANCELLATION=ROOT/'specs/019-traderx-security-lab/system/sql/execution-cancellation.sql'
ROLE='order-matcher'
PHASE='configuration'
PHASES={'configuration','images','fixture','broker_negatives','processor_start','matcher_bad_grant',
        'authorization','reservation','matcher_recovery','settlement','duplicate','cancellation','cleanup'}
CHECKS={'immutable_matcher_and_processor_images_revalidated','bad_service_credential_rejected_by_oauth_peer',
    'configured_matcher_broker_identity_cannot_publish_execution',
    'pending_reservation_has_exact_accepted_terms',
    'failed_grant_has_one_reservation_and_no_settlement','accepted_order_records_scoped_user_authority',
    'actual_price_subscriber_reserves_execution','same_image_retry_preserves_reserved_execution',
    'live_oauth_grant_and_https_processor_settle_order','exact_independent_trade_position_order_and_receipt',
    'two_exact_account_outbox_events','settlement_preserves_unrelated_business_and_all_reservations',
    'repeated_price_processed_without_duplicate_business_effects','duplicate_execution_request_idempotent',
    'authorized_cancellation_exact_state','cancellation_preserves_other_rows_and_has_no_reservation',
    'matcher_and_processor_sql_connections_verified_encrypted','owned_matcher_campaign_cleaned'}
CHECKS|={name+'_'+suffix for name in ('wrong_broker_ca','wrong_broker_hostname','wrong_broker_password')
         for suffix in ('boundary_rejection','no_effects')}
CHECKS|={name+'_'+suffix for name in ('anonymous','reader','foreign_account','wrong_audience','wrong_subject','malformed',
                                    'reader_cancel','foreign_account_read') for suffix in ('denied','no_effects')}
CHECKS|={role+'_'+suffix for role in ('matcher','processor') for suffix in ('restricted_private_runtime','credentials_not_exposed')}
ORDER=re.compile(r'ord-013-[0-9]{1,24}')


class Failure(RuntimeError):pass


def phase(name):
    global PHASE
    if name not in PHASES:raise ValueError('Unknown fixed phase')
    PHASE=name


def failure(error):
    code=str(error) if isinstance(error,Failure) else ''
    value={'status':'failed','phase':PHASE,'error':code if code in CHECKS else 'matcher_image_campaign_failed'}
    detail=getattr(error,'runtime_diagnostic',None)
    if detail:
        value['runtime']=bounded_runtime(detail)
        extras={'broker_tls','broker_io','broker_configuration','service_token_unavailable'}
        categories=detail.get('categories',[])
        value['runtime']['categories']+=sorted(extras & {item for item in categories[:32] if isinstance(item,str)}) if isinstance(categories,list) else []
    if isinstance(error,FixtureFailure):value['peer']=peer_diagnostic(error.details)
    from matcher_image_fixture import MatcherFixtureFailure, STAGES
    if isinstance(error,MatcherFixtureFailure) and error.stage in STAGES:value['matcher_peer_stage']=error.stage
    return value


def configs(f,matcher_password,processor_password):
    oauth=f['oauth'];expiry=datetime.datetime.fromtimestamp(time.time()+1800,datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    result={}
    for role,password in ((ROLE,matcher_password),('trade-processor',processor_password)):
        db=f['identities'][role]
        identity={'issuer':oauth['issuer'],'audience':'traderx-api' if role==ROLE else 'traderx-execution','key_not_after':expiry}
        if role=='trade-processor':identity['matcher_subject']=oauth['matcher_subject']
        result[role]={'version':1,'role':role,'database':{'host':'database','port':5432,'name':'traderx',
            'username':db['username'],'password':db['password']},'identity':identity,'tls':{'password':password}}
    result[ROLE].update(execution={'endpoint':'https://trade-processor:18091/internal/executions/',
        'token_endpoint':oauth['token_endpoint'],'client_id':oauth['client_id']},
        broker={'host':'nats-broker','port':4222,'username':'matcher'})
    return result


def bearer(f,subject='lab-trader',audience='traderx-api'):
    now=int(time.time())
    return jwt.encode({'iss':f['oauth']['issuer'],'sub':subject,'aud':audience,'iat':now-5,'exp':now+900},
                      f['oauth']['signing_key'],algorithm='RS256')


def payload(account=62654,security='IBM',quantity=2,limit=100):
    return json.dumps({'accountId':account,'security':security,'side':'Buy','quantity':quantity,'limitPrice':limit}).encode()


def order_id(raw):
    value=json.loads(raw).get('orderId')
    if not isinstance(value,str) or not ORDER.fullmatch(value):raise ValueError('Invalid created order identifier')
    return value


def wait_for(probe,seconds=30):
    deadline=time.monotonic()+seconds
    while time.monotonic()<deadline:
        value=probe()
        if value:return value
        time.sleep(.1)
    raise RuntimeError('Bounded observation unavailable')


def protected(f,orders=(),execution=None,reservations=False):
    if any(not ORDER.fullmatch(value) for value in orders):raise ValueError('Invalid owned order identifier')
    if execution is not None and str(uuid.UUID(execution))!=execution:raise ValueError('Invalid execution identifier')
    exclusions={
        'accounts':'','accountusers':'',
        'trades':f" WHERE id <> '{execution}'" if execution else '',
        'positions':" WHERE NOT (accountid=62654 AND security='IBM')" if execution else '',
        'orderbook':" WHERE orderid NOT IN ("+','.join("'"+value+"'" for value in orders)+')' if orders else ''}
    if reservations:exclusions['lab_execution.reservations']=''
    return {table:f['admin']("SELECT count(*),coalesce(md5(string_agg(x::text,'' ORDER BY x::text)),'empty') FROM (SELECT to_jsonb(t) x FROM "+table+' t'+where+') s;')
            for table,where in exclusions.items()}


def reservation_matches(rows,order,execution,issuer):
    return rows==[{'execution':execution,'order':order,'account':62654,'security':'IBM','side':'Buy',
        'quantity':2,'price':99,'subject':'lab-trader','issuer':issuer,'terms':order+'|62654|IBM|Buy|2|100'}]


def ledger_snapshot(f):
    return {table:f['admin']("SELECT count(*),coalesce(md5(string_agg(x::text,'' ORDER BY x::text)),'empty') FROM (SELECT to_jsonb(t) x FROM lab_execution."+table+' t) s;')
            for table in ('reservations','receipts','events')}


def broker_rejected(app,context,kind,authentication_before,f):
    deadline=time.monotonic()+90;served=False
    while app.inspect()['State'].get('Running') is True and time.monotonic()<deadline:
        try:app.request(context,'/actuator/health');served=True
        except (OSError,http.client.HTTPException):pass
        time.sleep(.25)
    detail=app.diagnostics()
    boundary=('broker_tls' in detail.get('categories',[]) if kind!='wrong_broker_password' else
              'broker_io' in detail.get('categories',[]) and f['broker_auth_rejections']()>authentication_before)
    return not served and detail['running'] is False and detail['exit_code'] not in (None,0,2) and not detail['oom_killed'] and boundary


def assert_restrictions(app,role,check):
    metadata=app.inspect()
    probe=json.loads(app.docker('exec',app.name,'/usr/local/bin/python','-c',images.PRIVATE_PROBE).stdout)
    images.check_restrictions(metadata,probe)
    private=json.loads(app.docker('exec',app.name,'/usr/local/bin/python','-c',private_java_probe(app.role)).stdout)
    check(private['files']=={name:[10001,10001,0o600] for name in KEYS[app.role]} and
          private['properties']==[10001,10001,0o600] and private['properties_directory']==[10001,10001,0o700] and
          private['listener'] is True and metadata['HostConfig']['Memory']==768*1024*1024 and
          metadata['HostConfig']['PidsLimit']==128 and not metadata['HostConfig'].get('PortBindings') and
          (app.role!='order-matcher' or private['truststore']==[10001,10001,0o600]),role+'_restricted_private_runtime')
    check(private['credentials_exposed'] is False,role+'_credentials_not_exposed')


def campaign(runtime,manifests):
    from matcher_image_fixture import fixture
    if not portability.isolated_linux() or os.environ.get('GITHUB_ACTIONS')!='true':raise ValueError('Hosted Linux required')
    if not isinstance(manifests,dict) or set(manifests)!={ROLE,'trade-processor'}:raise ValueError('Exact paired image manifests required')
    checks=[]
    def check(value,name):
        if name not in CHECKS:raise ValueError('Unknown fixed check')
        if not value:raise Failure(name)
        checks.append(name);print(json.dumps({'type':'matcher_image_checkpoint','check':name,'result':'passed','campaign_status':'incomplete'}),flush=True)
    phase('images');docker=images.Docker(runtime)
    identities={role:verified_image(manifest,docker,role) for role,manifest in manifests.items()}
    check(manifests[ROLE]['source_commit']==manifests['trade-processor']['source_commit'],'immutable_matcher_and_processor_images_revalidated')
    phase('fixture')
    with fixture(runtime) as f,tempfile.TemporaryDirectory(prefix='matcher-image-private-',dir=runtime) as temporary:
        root=Path(temporary)
        check(f['matcher_publication_denied'](),'configured_matcher_broker_identity_cannot_publish_execution')
        for path in (MIGRATION,SETTLEMENT,CANCELLATION,EVENTS):f['admin'](path.read_text())
        matcher_ca,matcher_p12,matcher_password=certificate_material(ROLE)
        processor_ca,processor_p12,processor_password=certificate_material('trade-processor')
        matcher_context=ssl.create_default_context(cadata=matcher_ca.decode());processor_context=ssl.create_default_context(cadata=processor_ca.decode())
        configuration=configs(f,matcher_password,processor_password)
        processor_material={'database-ca.pem':Path(f['database']['ca']).read_bytes(),'public.pem':f['oauth']['public_key'],'tls.p12':processor_p12}
        matcher_material=dict(processor_material,**{'tls.p12':matcher_p12,
            'entitlements.properties':b'lab-trader=trader:62654\nlab-reader=read-only:22214\nlab-operator=operator:\n',
            'broker-ca.pem':Path(f['broker']['ca']).read_bytes(),'identity-ca.pem':Path(f['oauth']['ca']).read_bytes(),
            'processor-ca.pem':processor_ca,'broker-secret':f['broker']['passwords']['matcher'].encode(),
            'client-secret':f['oauth']['client_secret'].encode()})
        def matcher(config=None,materials=None):return JavaImage(f,root,identities[ROLE],config or configuration[ROLE],materials or matcher_material)
        phase('broker_negatives');before=snapshot(f)
        for kind in ('wrong_broker_ca','wrong_broker_hostname','wrong_broker_password'):
            changed=copy.deepcopy(configuration[ROLE]);values=dict(matcher_material)
            if kind=='wrong_broker_ca':values['broker-ca.pem']=matcher_ca
            elif kind=='wrong_broker_hostname':changed['broker']['host']='wrong-broker'
            else:values['broker-secret']=secrets.token_hex(24).encode()
            rejected_before=f['broker_auth_rejections']()
            with matcher(changed,values).run() as app:
                check(broker_rejected(app,matcher_context,kind,rejected_before,f),kind+'_boundary_rejection')
            check(snapshot(f)==before,kind+'_no_effects')
        phase('processor_start')
        with JavaImage(f,root,identities['trade-processor'],configuration['trade-processor'],processor_material).run() as processor:
            processor.ready(processor_context);assert_restrictions(processor,'processor',check)
            phase('matcher_bad_grant')
            bad=dict(matcher_material,**{'client-secret':secrets.token_hex(24).encode()})
            with matcher(materials=bad).run() as app:
                app.ready(matcher_context);assert_restrictions(app,'matcher',check)
                phase('authorization');baseline=snapshot(f)
                for name,token,body in (
                    ('anonymous',None,payload()),('reader',bearer(f,'lab-reader'),payload(22214)),
                    ('foreign_account',bearer(f),payload(22214)),('wrong_audience',bearer(f,audience='traderx-execution'),payload()),
                    ('wrong_subject',bearer(f,'unknown-subject'),payload()),('malformed','not.a.jwt',payload())):
                    status,_=app.request(matcher_context,'/orders',bearer=token,method='POST',body=body)
                    check(status==(401 if name in ('anonymous','wrong_audience','malformed') else 403),name+'_denied')
                    check(snapshot(f)==baseline,name+'_no_effects')
                initial_protected=protected(f)
                status,raw=app.request(matcher_context,'/orders',bearer=bearer(f),method='POST',body=payload())
                if status!=201:raise RuntimeError('Authorized order creation unavailable')
                order=order_id(raw)
                check(f['admin'](f"SELECT acceptedsubject||'|'||acceptedissuer FROM orderbook WHERE orderid='{order}';")=='lab-trader|'+f['oauth']['issuer'],
                      'accepted_order_records_scoped_user_authority')
                phase('reservation');rejections=f['oauth_counts']()['rejected']
                f['publish_price'](99)
                wait_for(lambda:f['admin'](f"SELECT count(*) FROM lab_execution.reservations WHERE order_id='{order}';")=='1')
                check(True,'actual_price_subscriber_reserves_execution')
                execution=str(uuid.UUID(f['admin'](f"SELECT execution_id FROM lab_execution.reservations WHERE order_id='{order}';")))
                reserved=json.loads(f['admin']("SELECT coalesce(json_agg(json_build_object('execution',execution_id,'order',order_id,'account',account_id,'security',security,'side',side,'quantity',quantity,'price',price,'subject',accepted_subject,'issuer',accepted_issuer,'terms',accepted_terms)),'[]'::json) FROM lab_execution.reservations;"))
                check(reservation_matches(reserved,order,execution,f['oauth']['issuer']),'pending_reservation_has_exact_accepted_terms')
                wait_for(lambda:f['oauth_counts']()['rejected']>rejections)
                check(True,'bad_service_credential_rejected_by_oauth_peer')
                check(protected(f,orders=(order,))==initial_protected and f['admin']('SELECT count(*) FROM lab_execution.receipts;')=='0' and
                      f['admin']('SELECT count(*) FROM lab_execution.events;')=='0' and
                      f['admin'](f"SELECT remainingquantity||'|'||status FROM orderbook WHERE orderid='{order}';")=='2|NEW',
                      'failed_grant_has_one_reservation_and_no_settlement')
            phase('matcher_recovery');protected_before=protected(f,orders=(order,),execution=execution,reservations=True)
            grants=f['oauth_counts']()['accepted']
            with matcher().run() as app:
                app.ready(matcher_context)
                wait_for(lambda:f['admin'](f"SELECT status FROM orderbook WHERE orderid='{order}';")=='FILLED')
                check(f['admin'](f"SELECT count(*) FROM lab_execution.reservations WHERE order_id='{order}' AND execution_id='{execution}';")=='1',
                      'same_image_retry_preserves_reserved_execution')
                check(f['oauth_counts']()['accepted']>grants,'live_oauth_grant_and_https_processor_settle_order')
                phase('settlement')
                expected=f['admin'](f"SELECT (SELECT count(*) FROM lab_execution.receipts WHERE execution_id='{execution}' AND trade_id='{execution}'), (SELECT count(*) FROM trades WHERE id='{execution}' AND accountid=62654 AND security='IBM' AND side='Buy' AND quantity=2 AND price=99 AND state='Settled'), (SELECT count(*) FROM positions WHERE accountid=62654 AND security='IBM' AND quantity=2 AND averagecostbasis=99), (SELECT count(*) FROM orderbook WHERE orderid='{order}' AND accountid=62654 AND security='IBM' AND quantity=2 AND remainingquantity=0 AND status='FILLED' AND lastfillquantity=2 AND lastexecutionprice=99);")
                check(expected=='1|1|1|1' and f['admin']('SELECT count(*) FROM lab_execution.receipts;')=='1','exact_independent_trade_position_order_and_receipt')
                events=json.loads(f['admin']("SELECT coalesce(json_agg(json_build_object('id',event_id,'execution',execution_id,'kind',event_kind,'topic',topic,'account',payload->'accountId','quantity',payload->'quantity','delivered',delivered_at,'attempts',attempts) ORDER BY event_sequence),'[]'::json) FROM lab_execution.events;"))
                check(outbox_matches(events,execution),'two_exact_account_outbox_events')
                check(protected(f,orders=(order,),execution=execution,reservations=True)==protected_before,
                      'settlement_preserves_unrelated_business_and_all_reservations')
                phase('duplicate');stable=snapshot(f);f['publish_price'](98)
                def price_seen():
                    code,raw=app.request(matcher_context,'/orders/'+order,bearer=bearer(f))
                    return code==200 and json.loads(raw)['marketPrice']==98
                wait_for(price_seen)
                check(snapshot(f)==stable,'repeated_price_processed_without_duplicate_business_effects')
                code,raw=processor.request(processor_context,'/internal/executions/'+execution,
                    bearer=bearer(f,f['oauth']['matcher_subject'],'traderx-execution'),method='POST')
                check(code==200 and json.loads(raw)=={'executionId':execution,'tradeId':execution} and snapshot(f)==stable,
                      'duplicate_execution_request_idempotent')
                phase('cancellation')
                code,raw=app.request(matcher_context,'/orders',bearer=bearer(f),method='POST',body=payload(security='MSFT',quantity=3,limit=1))
                if code!=201:raise RuntimeError('Cancellation fixture creation unavailable')
                cancel=order_id(raw);stable=snapshot(f)
                for name,route,method in (('reader_cancel','/orders/'+cancel+'/cancel','POST'),('foreign_account_read','/orders/'+cancel,'GET')):
                    code,_=app.request(matcher_context,route,bearer=bearer(f,'lab-reader'),method=method)
                    check(code==403,name+'_denied');check(snapshot(f)==stable,name+'_no_effects')
                unchanged=protected(f,orders=(cancel,),reservations=True);unchanged_ledger=ledger_snapshot(f)
                code,_=app.request(matcher_context,'/orders/'+cancel+'/cancel',bearer=bearer(f),method='POST')
                check(code==200 and f['admin'](f"SELECT status||'|'||remainingquantity FROM orderbook WHERE orderid='{cancel}';")=='CANCELED|0',
                      'authorized_cancellation_exact_state')
                check(protected(f,orders=(cancel,),reservations=True)==unchanged and
                      ledger_snapshot(f)==unchanged_ledger and
                      f['admin'](f"SELECT count(*) FROM lab_execution.reservations WHERE order_id='{cancel}';")=='0',
                      'cancellation_preserves_other_rows_and_has_no_reservation')
                counts=f['admin']("SELECT usename,count(*),count(*) FILTER(WHERE s.ssl AND s.version IN ('TLSv1.2','TLSv1.3')) FROM pg_stat_activity a LEFT JOIN pg_stat_ssl s USING(pid) WHERE usename IN ('lab_order_matcher','lab_trade_processor') GROUP BY usename ORDER BY usename;").splitlines()
                check(len(counts)==2 and all(int(row.split('|')[1])>0 and row.split('|')[1]==row.split('|')[2] for row in counts),
                      'matcher_and_processor_sql_connections_verified_encrypted')
        peers={name:f[name]['image'] for name in ('database','broker')};phase('cleanup')
    check(True,'owned_matcher_campaign_cleaned')
    return {'status':'passed','source_commit':manifests[ROLE]['source_commit'],'images':identities,'peer_images':peers,'checks':checks,
        'counts':{'orders':2,'reservations':1,'receipts':1,'outbox_events':2},
        'source_sha256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in
            (Path(__file__).resolve(),ROOT/'scripts/security-lab/java_image_fixture.py',ROOT/'scripts/security-lab/matcher_image_fixture.py',MIGRATION,SETTLEMENT,CANCELLATION,EVENTS)},
        'limitations':['Strict synthetic OAuth client-credentials peer, not Keycloak provisioning; real Keycloak browser journey remains separate.',
            'Synthetic scoped IBM price producer; actual matcher and processor images, TLS and SQL effects.',
            'Outbox committed only; broker delivery and cumulative Kubernetes deployment remain separate acceptance boundaries.']}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-dir',type=Path,required=True);parser.add_argument('--images',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    if args.output.exists():raise ValueError('Evidence already exists')
    try:result=campaign(args.runtime_dir,json.loads(args.images.read_text()))
    except Exception as error:result=failure(error)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    with args.output.open('x') as output:json.dump(result,output,indent=2);output.write('\n')
    print(json.dumps(result));return 0 if result['status']=='passed' else 1


if __name__=='__main__':raise SystemExit(main())
