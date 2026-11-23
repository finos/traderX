#!/usr/bin/env python3
"""Verify the actual Spring account API with isolated test-signed access tokens."""
import argparse
import base64
from datetime import datetime,timezone,timedelta
import hashlib
import json
import os
from pathlib import Path
import secrets
import time
import urllib.request
import urllib.error
import uuid
import jwt
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives import serialization
from account_dev import ROOT,PROFILE,URL,render,run_compose,check_ownership,verify_files,start_services
from resource_operation import operation

ISSUER='https://localhost:18446/realms/traderx-lab'
AUDIENCE='traderx-account-api'


def request(method,path,token=None,body=None,headers=None):
    values={'Content-Type':'application/json',**(headers or {})}
    if token: values['Authorization']='Bearer '+token
    req=urllib.request.Request(URL+path,method=method,headers=values,data=None if body is None else json.dumps(body).encode())
    opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
    try:
        with opener.open(req,timeout=10) as response: status=response.status; data=response.read()
    except urllib.error.HTTPError as error: status=error.code; data=error.read()
    try: decoded=json.loads(data)
    except (ValueError,UnicodeDecodeError): decoded=None
    return status,decoded


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-dir',type=Path,default=Path('/private/tmp/traderx-security-runtime'))
    args=parser.parse_args();runtime=args.runtime_dir.resolve();folder=runtime/'account-dev'
    os.umask(0o077)
    with operation(runtime,'development'):
        build=json.loads((runtime/'evidence/account-security-build.json').read_text())
        jar=Path(build['jar'])
        if build['status']!='built-and-unit-tested-not-deployed' or hashlib.sha256(jar.read_bytes()).hexdigest()!=build['jar_sha256']:
            raise ValueError('Verified candidate build required')
        for name,digest in build['generation']['inputs'].items():
            if hashlib.sha256((ROOT/name).read_bytes()).hexdigest()!=digest: raise ValueError('Candidate source drift')
        check_ownership(runtime)
        run_id=uuid.uuid4().hex; private=runtime/'account-auth'/run_id;private.mkdir(parents=True,mode=0o700)
        config=private/'public-config';config.mkdir(mode=0o755)
        key=rsa.generate_private_key(public_exponent=65537,key_size=2048)
        other=rsa.generate_private_key(public_exponent=65537,key_size=2048)
        (private/'signing-key.pem').write_bytes(key.private_bytes(serialization.Encoding.PEM,serialization.PrivateFormat.PKCS8,serialization.NoEncryption()))
        (config/'public.pem').write_bytes(key.public_key().public_bytes(serialization.Encoding.PEM,serialization.PublicFormat.SubjectPublicKeyInfo))
        (config/'entitlements.properties').write_text('lab-reader=read-only:22214\nlab-trader=trader:62654\nlab-operator=operator:\n')
        for name,value in [('issuer',ISSUER),('audience',AUDIENCE),('key-not-after',(datetime.now(timezone.utc)+timedelta(hours=8)).isoformat())]: (config/name).write_text(value)
        output=runtime/'evidence/account-authorization.json'
        record={'run_id':run_id,'status':'running','started_at':datetime.now(timezone.utc).isoformat(),
                'scope':'real-Spring-account-API-with-test-signed-tokens','jar_sha256':build['jar_sha256'],
                'public_key_sha256':hashlib.sha256((config/'public.pem').read_bytes()).hexdigest(),
                'cycles':[],'limitations':['Test signer is not a live Keycloak login-to-API integration.',
                    'Loopback HTTP development only; C3, other APIs, browser sessions and broker authorization are unchanged.',
                    'Static public-key trust expires after eight hours; dynamic rotation/revocation is not implemented.',
                    'All account/membership writes are denied; privileged provisioning and trading authorization remain separate.']}
        def save(): output.write_text(json.dumps(record,indent=2)+'\n')
        save()
        try:
            if folder.exists():
                verify_files(folder)
                run_compose(runtime,folder,'down')
                folder.rename(private/'previous-development')
            render(folder,jar,config)
            start_services(runtime,folder)
            def sql(query):
                return run_compose(runtime,folder,'exec','-T','database','psql','-U','postgres','-d','accountdev','-At','-v','ON_ERROR_STOP=1','-c',query).strip()
            def fingerprint():
                query="SELECT json_build_object('accounts',(SELECT json_agg(t ORDER BY id) FROM accounts t),'memberships',(SELECT json_agg(t ORDER BY accountid,username) FROM accountusers t),'sequence',(SELECT json_build_object('value',last_value,'called',is_called) FROM accounts_seq));"
                return hashlib.sha256(sql(query).encode()).hexdigest()
            def token(subject='lab-reader',changes=None,algorithm='RS256',signing_key=None):
                now=int(time.time());claims=dict(iss=ISSUER,aud=AUDIENCE,sub=subject,iat=now-1,exp=now+120)
                for name,value in (changes or {}).items():
                    if value is None: claims.pop(name,None)
                    else: claims[name]=value
                return jwt.encode(claims,key if signing_key is None else signing_key,algorithm=algorithm)
            for cycle in range(2):
                if cycle:
                    run_compose(runtime,folder,'stop');run_compose(runtime,folder,'start')
                deadline=time.monotonic()+180
                while True:
                    try:
                        status,_=request('GET','/actuator/health')
                        if status==200:break
                    except (OSError,urllib.error.URLError):pass
                    if time.monotonic()>deadline:raise TimeoutError('Protected account startup')
                    time.sleep(1)
                before=fingerprint();results=[]
                def expect(case,method,path,wanted,bearer=None,body=None,headers=None,check=None):
                    status,data=request(method,path,bearer,body,headers)
                    if status!=wanted or (check and not check(data)):
                        raise ValueError(f'{case}: expected HTTP {wanted}, received {status} or mismatched content')
                    results.append({'id':case,'http_status':status,'outcome':'allowed' if status==200 else 'denied'})
                expect('anonymous-read','GET','/account/',401)
                expect('spoofed-identity-headers','GET','/account/22214',401,headers={'X-User':'lab-reader','X-Role':'operator','X-Account-ID':'22214'})
                for subject,own in [('lab-reader',22214),('lab-trader',62654),('lab-operator',None)]:
                    bearer=token(subject,{'accounts':[22214,62654],'roles':['operator'],'preferred_username':'reader'})
                    expected=set() if own is None else {own}
                    expect(subject+'-filtered-accounts','GET','/account/?accountId=62654',200,bearer,check=lambda rows: {r['id'] for r in rows}==expected)
                    expect(subject+'-filtered-memberships','GET','/accountuser/',200,bearer,check=lambda rows: {r['accountId'] for r in rows}==expected)
                    if own:
                        expect(subject+'-own-account','GET',f'/account/{own}',200,bearer,check=lambda row:row['id']==own)
                        expect(subject+'-own-membership','GET',f'/accountuser/{own}',200,bearer,check=lambda row:row['accountId']==own)
                    other_id=62654 if own==22214 else 22214
                    expect(subject+'-cross-account','GET',f'/account/{other_id}',403,bearer,headers={'X-Account-ID':str(other_id),'X-Role':'operator'})
                    expect(subject+'-cross-membership','GET',f'/accountuser/{other_id}',403,bearer)
                    expect(subject+'-unknown-object','GET','/account/999999',403,bearer)
                    for method in ('POST','PUT'):
                        expect(subject+'-'+method+'-account','%s'%method,'/account/',403,bearer,{'id':own or 22214,'displayName':'Unauthorized change'})
                        expect(subject+'-'+method+'-membership',method,'/accountuser/',403,bearer,{'accountId':other_id,'username':'operator'})
                expect('unmapped-principal','GET','/account/',403,token('unmapped',{'preferred_username':'reader'}))
                reader=token()
                for method in ('DELETE','PATCH','HEAD','OPTIONS'):
                    expect('unlisted-method-'+method,method,'/account/22214',403,reader)
                expect('unlisted-operator-route','GET','/actuator/prometheus',403,reader)
                expect('cross-origin-access','GET','/account/',403,reader,headers={'Origin':'https://untrusted.invalid'})
                now=int(time.time())
                changes=[('wrong-issuer',{'iss':ISSUER+'/other'}),('wrong-audience',{'aud':'another-api'}),
                    ('id-token-audience',{'aud':'security-lab-browser'}),('expired',{'iat':now-100,'exp':now-1}),
                    ('future-issued-at',{'iat':now+60}),('future-not-before',{'nbf':now+60}),
                    ('missing-expiry',{'exp':None}),('missing-issued-at',{'iat':None}),('missing-subject',{'sub':None}),
                    ('blank-subject',{'sub':''}),('missing-audience',{'aud':None})]
                for name,claims in changes: expect(name,'GET','/account/',401,token(changes=claims))
                for name,bearer in [('wrong-signature',token(signing_key=other)),('wrong-rsa-algorithm',token(algorithm='RS512')),
                    ('hmac-algorithm',token(algorithm='HS256',signing_key=secrets.token_bytes(32))),
                    ('unsigned',token(algorithm='none',signing_key='')),('malformed','not-a-token')]:
                    expect(name,'GET','/account/',401,bearer)
                parts=reader.split('.');parts[1]=base64.urlsafe_b64encode(json.dumps({'sub':'lab-operator'}).encode()).decode().rstrip('=')
                expect('tampered-token','GET','/account/',401,'.'.join(parts))
                after=fingerprint()
                if before!=after:raise ValueError('Denied requests changed authoritative database state')
                # Empty-list edge case is changed only by the independent reset identity.
                sql('TRUNCATE accountusers, accounts;')
                expect('unmapped-empty-list','GET','/account/',403,token('unmapped'))
                expect('mapped-empty-list','GET','/account/',200,token(),check=lambda rows:rows==[])
                sql("INSERT INTO accounts VALUES (22214,'Synthetic reader account'),(62654,'Synthetic trader account'); INSERT INTO accountusers VALUES (22214,'reader'),(62654,'trader');")
                if fingerprint()!=before:raise ValueError('Empty-list fixture did not restore exact synthetic state')
                record['cycles'].append({'cycle':cycle+1,'cases':results,'before_sha256':before,'after_denials_sha256':after,'reset_restored':True})
                save();print(f'Protected API cycle {cycle+1}: {len(results)} cases passed; database unchanged.',flush=True)
            record['status']='passed'
        except BaseException as error:
            record.update(status='failed',failure_type=type(error).__name__);raise
        finally:
            record['finished_at']=datetime.now(timezone.utc).isoformat()
            record['source_sha256']={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [Path(__file__).resolve(),ROOT/'scripts/security-lab/account_dev.py']}
            save()

if __name__=='__main__':main()
