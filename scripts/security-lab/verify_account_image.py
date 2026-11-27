"""Hosted acceptance of immutable scoped account/account-user HTTPS reads."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import ssl
import tempfile
import time
import zipfile

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
import jwt

import java_image_fixture as shared
import portability
import verify_runtime_images as images
from verify_bootstrap import fingerprint
from verify_worker_images import peer_diagnostic
from worker_image_fixture import fixture,FixtureFailure

ROOT=Path(__file__).resolve().parents[2]
ROLE='account-service';ISSUER='https://identity.example.test/account-image';AUDIENCE='traderx-api'
KEYS=shared.KEYS[ROLE]
PHASE='configuration'
PHASES=frozenset(('configuration','image','fixture','wrong_database_ca','startup','restrictions','authorization','sql_tls','cleanup'))
INVALID_TOKENS=('malformed','invalid_signature','foreign_issuer','foreign_audience','expired')
CHECKS=frozenset(('immutable_account_image_revalidated','actual_jar_has_no_people_or_legacy_write_dependency',
    'untrusted_database_ca_terminates_startup','untrusted_database_ca_no_data_effects','verified_https_database_health_up',
    'restricted_runtime_and_private_materialization','no_credentials_in_argv_or_environment',
    'https_untrusted_client_ca_rejected','https_mismatched_hostname_rejected','operator_has_no_implicit_account_scope',
    'reader_and_operator_privileged_routes_denied','all_identity_write_routes_denied','legacy_routes_denied',
    'runtime_sql_connections_all_encrypted','runtime_sql_role_is_scoped_nonadmin','unrelated_table_access_denied',
    'all_reads_and_rejections_leave_business_data_unchanged','owned_image_fixture_cleaned')) | frozenset(
    kind+'_'+case for kind in ('account','accountuser') for case in (
        'anonymous_denied','unknown_subject_denied',*[v+'_denied' for v in INVALID_TOKENS],
        'reader_collection_scoped','trader_collection_scoped','reader_own_account_scoped','trader_own_account_scoped',
        'reader_cross_account_denied','trader_cross_account_denied'))
ERRORS=CHECKS|frozenset(('hosted_linux_required','image_manifest_invalid','image_manifest_drift','loaded_image_changed',
    'private_projection_failed','private_output_detected','java_startup_failed','java_startup_timeout',
    'worker_cleanup_ownership','http_body_bound','fixture_read_rows_missing'))
Failure=shared.Failure


def phase(name):
    global PHASE
    if name not in PHASES:raise ValueError('Unknown fixed phase')
    PHASE=name


def failure(error):
    code=str(error) if isinstance(error,Failure) else ''
    result={'status':'failed','phase':PHASE,'error':code if code in ERRORS else 'account_image_campaign_failed'}
    if isinstance(error,FixtureFailure):result['peer']=peer_diagnostic(error.details)
    if hasattr(error,'runtime_diagnostic'):result['runtime']=error.runtime_diagnostic
    return result


def configuration(f,password):
    credentials=f['identities'][ROLE]
    return {'version':1,'role':ROLE,'database':{'host':'database','port':5432,'name':'traderx',
        'username':credentials['username'],'password':credentials['password']},
        'identity':{'issuer':ISSUER,'audience':AUDIENCE,'key_not_after':datetime.datetime.fromtimestamp(time.time()+1800,datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')},
        'tls':{'password':password}}


def token(key,subject='lab-reader',variant=None):
    if variant=='malformed':return 'not.a.jwt'
    now=int(time.time());claims={'sub':subject,'iss':ISSUER,'aud':AUDIENCE,'iat':now-5,'exp':now+900}
    if variant=='foreign_issuer':claims['iss']='https://foreign.example.test'
    elif variant=='foreign_audience':claims['aud']='foreign-api'
    elif variant=='expired':claims.update(iat=now-300,exp=now-60)
    elif variant not in (None,'invalid_signature'):raise ValueError('Unknown fixture token variant')
    return jwt.encode(claims,key,algorithm='RS256')


def rows_match(raw,expected,kind,account,single=False):
    value=json.loads(raw);rows=[value] if single else value
    keys=('id','displayName') if kind=='account' else ('accountId','username')
    if not isinstance(rows,list) or not rows or not expected:return False
    if any(not isinstance(row,dict) or set(row)!=set(keys) or type(row[keys[0]]) is not int
           or row[keys[0]]!=account or not isinstance(row[keys[1]],str) for row in rows):return False
    reference=expected[:1] if single else expected
    return sorted(tuple(row[key] for key in keys) for row in rows)==sorted(tuple(row[key] for key in keys) for row in reference)


def no_people_dependency(jar):
    """Inspect the same verified bootJar: known outbound bean and writes are absent."""
    with zipfile.ZipFile(jar) as archive:
        entries=[v for v in archive.infolist() if v.filename.startswith('BOOT-INF/classes/finos/traderx/accountservice/') and v.filename.endswith('.class')]
        if not entries or sum(v.file_size for v in entries)>4*1024*1024:return False
        for entry in entries:
            if entry.file_size>512*1024 or 'PeopleValidationService' in entry.filename:return False
            content=archive.read(entry)
            if b'PeopleValidationService' in content or b'org/springframework/web/client/RestTemplate' in content:return False
            if entry.filename.endswith(('controller/AccountController.class','controller/AccountUserController.class')):
                if any(value in content for value in (b'PostMapping',b'PutMapping',b'RequestBody')):return False
        config=archive.getinfo('BOOT-INF/classes/application.properties')
        return config.file_size<=65536 and b'people.service.url' not in archive.read(config)


def authorize(app,context,signing,alternate,expected,check):
    for kind in ('account','accountuser'):
        check(app.request(context,'/'+kind+'/')[0]==401,kind+'_anonymous_denied')
        for variant in INVALID_TOKENS:
            bad=token(alternate if variant=='invalid_signature' else signing,variant=variant)
            check(app.request(context,'/'+kind+'/',bad)[0]==401,kind+'_'+variant+'_denied')
        check(app.request(context,'/'+kind+'/',token(signing,'unknown-subject'))[0]==403,kind+'_unknown_subject_denied')
        for role,account,other in (('reader',22214,62654),('trader',62654,22214)):
            bearer=token(signing,'lab-'+role)
            for suffix,label in (('','collection_scoped'),(str(account),'own_account_scoped')):
                status,raw=app.request(context,'/'+kind+'/'+suffix,bearer)
                check(status==200 and rows_match(raw,expected[kind,account],kind,account,bool(suffix)),kind+'_'+role+'_'+label)
            check(app.request(context,'/'+kind+'/'+str(other),bearer)[0]==403,kind+'_'+role+'_cross_account_denied')
    operator=token(signing,'lab-operator')
    check(all(app.request(context,'/'+kind+'/',operator)==(200,b'[]') and
              app.request(context,'/'+kind+'/22214',operator)[0]==403 for kind in ('account','accountuser')),
          'operator_has_no_implicit_account_scope')
    check(all(app.request(context,path,token(signing,subject))[0]==403
        for subject in ('lab-reader','lab-operator') for path in ('/actuator/env','/actuator/prometheus','/metrics','/system/health')),
        'reader_and_operator_privileged_routes_denied')
    check(all(app.request(context,'/'+kind+'/'+suffix,token(signing,subject),method=method,
              body=json.dumps({'id':22214,'displayName':'Unauthorized'} if kind=='account' else {'accountId':22214,'username':'unauthorized'}).encode())[0]==403
        for subject in ('lab-reader','lab-trader','lab-operator') for kind in ('account','accountuser')
        for suffix in ('','22214') for method in ('POST','PUT','PATCH','DELETE')),'all_identity_write_routes_denied')
    check(all(app.request(context,path,operator,method=method)[0]==403
        for path in ('/trade/','/orders','/people/','/internal/executions/00000000-0000-4000-8000-000000000001')
        for method in ('GET','POST')),'legacy_routes_denied')


def campaign(runtime,manifest):
    if not portability.isolated_linux() or os.environ.get('GITHUB_ACTIONS')!='true':raise Failure('hosted_linux_required')
    checks=[]
    def check(value,name):
        if name not in CHECKS:raise ValueError('Unknown fixed acceptance check')
        if not value:raise Failure(name)
        checks.append(name)
        print(json.dumps({'type':'account_image_checkpoint','check':name,'result':'passed','campaign_status':'incomplete'}),flush=True)
    phase('image');identity=shared.verified_image(manifest,images.Docker(runtime),ROLE)
    check(True,'immutable_account_image_revalidated')
    check(no_people_dependency(Path(manifest['generated_root'])/'build/libs/account-service-specfirst-0.1.0.jar'),
          'actual_jar_has_no_people_or_legacy_write_dependency')
    phase('fixture')
    with fixture(runtime) as f,tempfile.TemporaryDirectory(prefix='account-image-private-',dir=runtime) as temporary:
        root=Path(temporary);ca,bundle,password=shared.certificate_material(ROLE)
        context=ssl.create_default_context(cadata=ca.decode());signing=rsa.generate_private_key(public_exponent=65537,key_size=2048)
        alternate=rsa.generate_private_key(public_exponent=65537,key_size=2048);config=configuration(f,password)
        materials={'database-ca.pem':Path(f['database']['ca']).read_bytes(),'tls.p12':bundle,
            'public.pem':signing.public_key().public_bytes(serialization.Encoding.PEM,serialization.PublicFormat.SubjectPublicKeyInfo),
            'entitlements.properties':b'lab-reader=read-only:22214\nlab-trader=trader:62654\nlab-operator=operator:\n'}
        expected={}
        for account in (22214,62654):
            f['admin'](f"INSERT INTO accountusers(accountid,username) SELECT {account},'lab-image-{account}' WHERE NOT EXISTS(SELECT 1 FROM accountusers WHERE accountid={account} AND username='lab-image-{account}');")
            for kind,table,fields,idcolumn,order in (
                ('account','accounts',"'id',id,'displayName',displayname",'id','id'),
                ('accountuser','accountusers',"'accountId',accountid,'username',username",'accountid','username')):
                expected[kind,account]=json.loads(f['admin'](f"SELECT coalesce(json_agg(json_build_object({fields}) ORDER BY {order}),'[]'::json) FROM {table} WHERE {idcolumn}={account};"))
                if not expected[kind,account]:raise Failure('fixture_read_rows_missing')
        before=fingerprint(f['sql'],f['database_password']);phase('wrong_database_ca')
        with shared.JavaImage(f,root,identity,config,dict(materials,**{'database-ca.pem':ca})).run() as app:
            check(shared.wrong_database_ca_stopped(app,context),'untrusted_database_ca_terminates_startup')
        check(fingerprint(f['sql'],f['database_password'])==before,'untrusted_database_ca_no_data_effects')
        phase('startup')
        with shared.JavaImage(f,root,identity,config,materials).run() as app:
            app.ready(context);check(True,'verified_https_database_health_up');phase('restrictions')
            inspected=app.inspect();probe=json.loads(app.docker('exec',app.name,'/usr/local/bin/python','-c',images.PRIVATE_PROBE).stdout)
            images.check_restrictions(inspected,probe)
            private=json.loads(app.docker('exec',app.name,'/usr/local/bin/python','-c',shared.private_java_probe(ROLE)).stdout)
            check(private['files']=={name:[10001,10001,0o600] for name in KEYS} and
                private['properties']==[10001,10001,0o600] and private['properties_directory']==[10001,10001,0o700]
                and private['listener'] is True and inspected['HostConfig']['Memory']==768*1024*1024
                and inspected['HostConfig']['PidsLimit']==128 and not inspected['HostConfig'].get('PortBindings'),
                'restricted_runtime_and_private_materialization')
            check(private['credentials_exposed'] is False,'no_credentials_in_argv_or_environment')
            for name,bad_context,hostname in (('https_untrusted_client_ca_rejected',ssl.create_default_context(),ROLE),
                ('https_mismatched_hostname_rejected',context,'wrong-account-service')):
                rejected=False
                try:app.request(bad_context,'/actuator/health',hostname=hostname)
                except ssl.SSLCertVerificationError:rejected=True
                check(rejected,name)
            phase('authorization');authorize(app,context,signing,alternate,expected,check);phase('sql_tls')
            role=f['identities'][ROLE]['username']
            counts=f['admin'](f"SELECT count(*),count(*) FILTER(WHERE s.ssl AND s.version IN ('TLSv1.2','TLSv1.3')) FROM pg_stat_activity a LEFT JOIN pg_stat_ssl s USING(pid) WHERE a.usename='{role}';").split('|')
            check(len(counts)==2 and int(counts[0])>0 and counts[0]==counts[1],'runtime_sql_connections_all_encrypted')
            flags=f['admin'](f"SELECT rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls FROM pg_roles WHERE rolname='{role}';")
            check(role=='lab_account' and flags=='f','runtime_sql_role_is_scoped_nonadmin')
            denied=f['sql'](role,config['database']['password'],'SELECT count(*) FROM positions;')
            check(denied.returncode!=0 and '42501' in denied.stderr,'unrelated_table_access_denied')
            check(fingerprint(f['sql'],f['database_password'])==before,'all_reads_and_rejections_leave_business_data_unchanged')
        peer_images={name:f[name]['image'] for name in ('database','broker')};phase('cleanup')
    check(True,'owned_image_fixture_cleaned')
    if len(checks)!=len(CHECKS) or set(checks)!=CHECKS:raise ValueError('Incomplete account acceptance inventory')
    return {'status':'passed','role':ROLE,'source_commit':manifest['source_commit'],'image':identity,'peer_images':peer_images,
        'checks':checks,'resource_limits':{'memory_mib':768,'pids':128,'tmp_mib':64},
        'source_sha256':{str(path.relative_to(ROOT)):hashlib.sha256(path.read_bytes()).hexdigest() for path in (
            Path(__file__).resolve(),ROOT/'scripts/security-lab/java_image_fixture.py',ROOT/'scripts/security-lab/worker_image_fixture.py',
            ROOT/'scripts/security-lab/render_account_security.py',ROOT/'scripts/security-lab/java_runtime.py',ROOT/'scripts/security-lab/java_images.py')},
        'limitations':['Fixture JWTs and finite static trust; no live Keycloak or key rotation acceptance.',
            'Known people-directory client and write handlers absent from verified JAR; no cluster egress enforcement claim.',
            'Scoped SQL login retains its defined table grants; only protected HTTP profile is read-only.',
            'Owned fixture includes unused NATS; no Kubernetes deployment or full browser workflow acceptance.']}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-dir',type=Path,required=True);parser.add_argument('--image','--manifest',dest='image',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    if args.output.exists():raise ValueError('Evidence already exists')
    try:result=campaign(args.runtime_dir,json.loads(args.image.read_text()))
    except Exception as error:result=failure(error)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    with args.output.open('x') as output:json.dump(result,output,indent=2);output.write('\n')
    print(json.dumps(result));return 0 if result['status']=='passed' else 1


if __name__=='__main__':raise SystemExit(main())
