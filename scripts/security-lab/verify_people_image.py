"""Hosted immutable .NET image acceptance with scoped synthetic identities."""
import argparse
import copy
import datetime
import hashlib
import http.client
import json
import os
from pathlib import Path
import ssl
import time

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
import jwt

import people_runtime
import people_image_fixture as fixture
import verify_runtime_images as images

ISSUER='https://identity.example.test/people-image'
AUDIENCE='traderx-people-service'
PATH='/People/GetPerson?logonId=user01'
PHASE='configuration'
CHECKS={'immutable_people_image_revalidated','native_culture_operations_pass','verified_https_ready',
 'restricted_private_runtime','exact_private_launcher_and_environment','packaged_directory_unchanged',
 'native_icu_libraries_loaded','operator_exact_packaged_person','operator_bounded_search','operator_validation',
 'directory_response_no_store_no_cors','untrusted_https_ca_rejected','wrong_https_hostname_rejected',
 'same_image_restart_preserves_directory_result','expired_trust_snapshot_denies_operator','expired_trust_retains_liveness',
 'owned_people_image_fixture_cleaned'}
VARIANTS=('anonymous','reader','trader','unknown_subject','malformed','wrong_signature','wrong_issuer','wrong_audience','expired','provider_role_only')
CHECKS|={name+'_denied_without_directory' for name in VARIANTS}
ROUTES={'swagger':'/swagger/index.html','metrics':'/metrics','wrong_case':'/people/GetPerson','trailing_slash':'/People/GetPerson/',
 'private_config':'/run/private/config/config.json','private_key':'/run/private/config/server-key.pem'}
CHECKS|={name+'_unavailable' for name in (*ROUTES,'mutation')}
CHECKS|={'oversized_query_rejected','short_query_rejected','ambiguous_query_rejected'}


def configuration(expiry=1200):
    return {'version':1,'issuer':ISSUER,'audience':AUDIENCE,
        'key_not_after':datetime.datetime.fromtimestamp(time.time()+expiry,datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
        'public_key_file':'/run/private/config/identity-public.pem','roles_file':'/run/private/config/identity-roles.json',
        'server_certificate_file':'/run/private/config/server-cert.pem','server_key_file':'/run/private/config/server-key.pem'}


def bearer(signing,alternate,variant=None):
    if variant=='anonymous':return None
    if variant=='malformed':return 'not.a.jwt'
    now=int(time.time());claims={'iss':ISSUER,'aud':AUDIENCE,'sub':'lab-operator','iat':now-2,'exp':now+600}
    if variant in ('reader','trader'):claims['sub']='lab-'+variant
    elif variant in ('unknown_subject','provider_role_only'):
        claims['sub']='unknown' if variant=='unknown_subject' else 'lab-reader'
        claims['realm_access']={'roles':['operator']};claims['role']='operator'
    elif variant=='wrong_issuer':claims['iss']='https://other.example.test'
    elif variant=='wrong_audience':claims['aud']='traderx-api'
    elif variant=='expired':claims.update(iat=now-120,exp=now-60)
    elif variant not in (None,'wrong_signature'):raise ValueError('Unknown fixed identity case')
    return jwt.encode(claims,alternate if variant=='wrong_signature' else signing,algorithm='RS256')


def expected_person(manifest):
    path=Path(manifest['generated_root'])/'PeopleService.WebApi/MockDirectory/people.json'
    data=path.read_bytes();people=json.loads(data)
    person=next(row for row in people if row['LogonId']=='user01')
    return {key[0].lower()+key[1:]:value for key,value in person.items()},hashlib.sha256(data).hexdigest()


def native_probe(f,identity,root):
    from build_people_native_probe import verify
    report=verify(root)
    name='traderx-people-native-'+f['owner'];f['names'].append(name)
    result=f['docker']('run','--name',name,'--label',images.LABEL+'='+f['owner'],'--network','none',
        '--user','10001:10001','--read-only','--cap-drop','ALL','--security-opt','no-new-privileges:true',
        '--memory','256m','--memory-swap','256m','--cpus','1','--pids-limit','64',
        '--tmpfs','/tmp:rw,noexec,nosuid,nodev,uid=10001,gid=10001,mode=0700,size=8m',
        '--mount','type=bind,src='+str(Path(root)/'publish')+',dst=/run/native-probe,readonly',
        '--entrypoint','/usr/share/dotnet/dotnet',identity['runtime_id'],'/run/native-probe/PeopleNativeProbe.dll',
        check=False,timeout=30)
    # Probe has no private configuration; only its fixed pass document can enter evidence.
    if result.returncode!=0:raise fixture.Failure('native_probe_failed')
    value=json.loads(result.stdout)
    if value!={'status':'passed','turkish_uppercase':True,'french_decimal':True}:raise fixture.Failure('native_probe_result')
    return {'result':value,'report_sha256':hashlib.sha256(json.dumps(report,sort_keys=True).encode()).hexdigest(),
            'scope':'Separate fixed culture probe in the same immutable image; application startup is checked independently.'}


def campaign(runtime,manifest):
    global PHASE
    if not fixture.portability.isolated_linux() or os.environ.get('GITHUB_ACTIONS')!='true':raise fixture.Failure('hosted_linux_required')
    checks=[]
    def check(value,name):
        if name not in CHECKS:raise ValueError('Unknown fixed check')
        if not value:raise fixture.Failure(name)
        checks.append(name);print(json.dumps({'type':'people_image_checkpoint','check':name,'result':'passed','campaign_status':'incomplete'}),flush=True)
    PHASE='image';identity=fixture.verified_image(manifest,images.Docker(runtime));check(True,'immutable_people_image_revalidated')
    expected,directory_hash=expected_person(manifest)
    PHASE='fixture'
    with fixture.fixture(runtime) as f:
        PHASE='native';native=native_probe(f,identity,manifest['native_probe']);check(True,'native_culture_operations_pass')
        values,_=images.certificates(f['root'],'127.0.0.1')
        context=ssl.create_default_context(cadata=values['ca.pem'].decode())
        signing=rsa.generate_private_key(public_exponent=65537,key_size=2048);alternate=rsa.generate_private_key(public_exponent=65537,key_size=2048)
        material={'server-cert.pem':values['tls.crt'],'server-key.pem':values['tls.key'],
            'identity-public.pem':signing.public_key().public_bytes(serialization.Encoding.PEM,serialization.PublicFormat.SubjectPublicKeyInfo),
            'identity-roles.json':json.dumps({'lab-reader':'read-only','lab-trader':'trader','lab-operator':'operator'}).encode()}
        config=configuration()
        PHASE='startup'
        with fixture.PeopleImage(f,identity,config,material).run() as app:
            app.ready(context);check(True,'verified_https_ready')
            metadata=app.inspect();probe=json.loads(app.docker('exec',app.name,'/usr/local/bin/python','-c',images.PRIVATE_PROBE).stdout)
            images.check_restrictions(metadata,probe)
            check(metadata['HostConfig']['Memory']==256*1024*1024 and metadata['HostConfig']['PidsLimit']==64 and not metadata['HostConfig'].get('PortBindings'),'restricted_private_runtime')
            for name,tls,hostname in (('untrusted_https_ca_rejected',ssl.create_default_context(),'localhost'),('wrong_https_hostname_rejected',context,'wrong.example.test')):
                rejected=False
                try:app.request(tls,'/health/alive',hostname=hostname)
                except ssl.SSLCertVerificationError:rejected=True
                check(rejected,name)
            PHASE='authorization'
            for variant in VARIANTS:
                status,_,body=app.request(context,PATH,bearer=bearer(signing,alternate,variant),headers={'X-Role':'operator'})
                expected_status=403 if variant in ('reader','trader','unknown_subject','provider_role_only') else 401
                check(status==expected_status and b'user01' not in body and b'Alice' not in body,variant+'_denied_without_directory')
            token=bearer(signing,alternate)
            status,headers,body=app.request(context,PATH,bearer=token)
            check(status==200 and json.loads(body)==expected,'operator_exact_packaged_person')
            check(headers.get('cache-control')=='no-store' and 'access-control-allow-origin' not in headers,'directory_response_no_store_no_cors')
            status,_,body=app.request(context,'/People/GetMatchingPeople?searchText=Alice&take=1',bearer=token)
            check(status==200 and json.loads(body)=={'people':[expected]},'operator_bounded_search')
            status,_,body=app.request(context,'/People/ValidatePerson?employeeId=E0001',bearer=token)
            check(status==200 and body==b'','operator_validation')
            for name,path in ROUTES.items():check(app.request(context,path,bearer=token)[0]==404,name+'_unavailable')
            check(app.request(context,'/People/GetPerson',bearer=token,method='POST')[0]==404,'mutation_unavailable')
            for name,path in (('oversized_query','/People/GetMatchingPeople?searchText=Alice&take=9999'),('short_query','/People/GetMatchingPeople?searchText=Al'),('ambiguous_query','/People/GetPerson?logonId=user01&employeeId=E0001')):
                check(app.request(context,path,bearer=token)[0]==400,name+'_rejected')
            private=json.loads(app.docker('exec',app.name,'/usr/local/bin/python','-c',fixture.PRIVATE_PROBE).stdout)
            check(private['files']=={name:[10001,10001,0o600] for name in people_runtime.FILES} and private['directory']==[10001,10001,0o700] and private['exact_environment'] and private['exact_command'] and not private['private_key_exposed'],'exact_private_launcher_and_environment')
            check(private['directory_sha256']==directory_hash,'packaged_directory_unchanged')
            check(private['icu_loaded'],'native_icu_libraries_loaded')
        PHASE='restart'
        with fixture.PeopleImage(f,identity,config,material).run() as app:
            app.ready(context);status,_,body=app.request(context,PATH,bearer=bearer(signing,alternate))
            check(status==200 and json.loads(body)==expected,'same_image_restart_preserves_directory_result')
        PHASE='trust_expiry';short=configuration(20)
        with fixture.PeopleImage(f,identity,short,material).run() as app:
            app.ready(context)
            if app.request(context,PATH,bearer=bearer(signing,alternate))[0]!=200:raise fixture.Failure('preexpiry_operator_unavailable')
            expiry=datetime.datetime.fromisoformat(short['key_not_after'].replace('Z','+00:00')).timestamp()
            time.sleep(max(0,expiry-time.time())+.2)
            status,_,body=app.request(context,PATH,bearer=bearer(signing,alternate))
            check(status==401 and b'user01' not in body,'expired_trust_snapshot_denies_operator')
            check(app.request(context,'/health/alive')[0]==200,'expired_trust_retains_liveness')
        PHASE='cleanup'
    check(True,'owned_people_image_fixture_cleaned')
    return {'status':'passed','source_commit':manifest['source_commit'],'image':identity,'checks':checks,
        'directory_sha256':directory_hash,'native_probe':native,
        'limitations':['Static synthetic JWT trust tests the image interface, not live provider provisioning or key rotation.',
            'Directory remains operator-only and read-only; subject/person binding and live grant reload remain separate.',
            'Pinned .NET 9 is inherited from C3; supported-runtime migration is required before release.',
            'No cumulative Kubernetes, gateway, CNI, performance or production-readiness acceptance follows.']}


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--runtime-dir',type=Path,required=True)
    parser.add_argument('--image',type=Path,required=True);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    os.umask(0o077)
    if args.output.exists():raise ValueError('Fresh evidence required')
    try:result=campaign(args.runtime_dir,json.loads(args.image.read_text()))
    except Exception as error:
        result={'status':'failed','phase':PHASE,'error':error.code if isinstance(error,fixture.Failure) else 'people_image_campaign_failed'}
        if isinstance(error,fixture.Failure) and error.diagnostic:result['runtime']=error.diagnostic
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result));return 0 if result['status']=='passed' else 1

if __name__=='__main__':raise SystemExit(main())
