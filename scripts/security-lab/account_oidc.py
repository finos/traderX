"""Connect the disposable real OIDC issuer to the opt-in Spring candidate."""
from datetime import datetime, timezone, timedelta
import hashlib
import json
from pathlib import Path
import time
import jwt
from cryptography.hazmat.primitives import serialization
from account_dev import ROOT, verify_files, run_compose
from identity_fixture import ISSUER, AUDIENCE
from verify_account_authorization import request


def replace_trust(runtime, jwks, trust_hours=1):
    if not 0 < trust_hours <= 8: raise ValueError("Trust window must be within eight hours")
    folder=runtime/'account-dev'; verify_files(folder)
    manifest=json.loads((folder/'manifest.json').read_text())
    if not manifest.get('identity_configured'): raise ValueError('Protected candidate required')
    build=json.loads((runtime/'evidence/account-security-build.json').read_text())
    if hashlib.sha256((folder/'candidate.jar').read_bytes()).hexdigest()!=build['jar_sha256']:
        raise ValueError('Candidate artifact drift')
    for name,digest in build['generation']['inputs'].items():
        if hashlib.sha256((ROOT/name).read_bytes()).hexdigest()!=digest: raise ValueError('Candidate source drift')
    keys=[k for k in jwks['keys'] if k.get('alg')=='RS256' and k.get('use')=='sig' and k.get('kty')=='RSA']
    if len(keys)!=1: raise ValueError('Exactly one approved fixture signing key required')
    public=jwt.PyJWK.from_dict(keys[0]).key.public_bytes(serialization.Encoding.PEM,serialization.PublicFormat.SubjectPublicKeyInfo)
    run_compose(runtime,folder,'stop','account')
    updates={'public.pem':public.decode(),'lab.identity.issuer':ISSUER,'lab.identity.audience':AUDIENCE,
             'lab.identity.key-not-after':(datetime.now(timezone.utc)+timedelta(hours=trust_hours)).isoformat()}
    for name,value in updates.items():
        path=folder/'account'/name; path.write_text(value);path.chmod(0o644)
        manifest['files']['account/'+name]=hashlib.sha256(path.read_bytes()).hexdigest()
    (folder/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    run_compose(runtime,folder,'start','account')
    deadline=time.monotonic()+180
    while time.monotonic()<deadline:
        try:
            if request('GET','/actuator/health')[0]==200: return public
        except OSError: pass
        time.sleep(1)
    raise TimeoutError('Protected API readiness after trust replacement')


def verify_user(name,tokens,passed):
    own={'reader':22214,'trader':62654,'operator':None}[name]
    token=tokens['access_token']; expected=[] if own is None else [own]
    status,rows=request('GET','/account/',token)
    if status!=200 or sorted(r['id'] for r in rows)!=expected: raise ValueError('Real-provider account scope mismatch')
    passed(name+'-real-provider-filtered-account-api')
    status,rows=request('GET','/accountuser/',token)
    if status!=200 or sorted(r['accountId'] for r in rows)!=expected: raise ValueError('Real-provider membership scope mismatch')
    passed(name+'-real-provider-filtered-membership-api')
    if own:
        if request('GET','/account/'+str(own),token)[0]!=200: raise ValueError('Own-account denied')
        passed(name+'-real-provider-own-account')
    other=62654 if own==22214 else 22214
    for path in ('/account/','/accountuser/'):
        if request('GET',path+str(other),token)[0]!=403: raise ValueError('Cross-account authorization failure')
        passed(name+'-real-provider-cross-'+path.strip('/')+'-denied')
        for method in ('POST','PUT'):
            if request(method,path,token,{'accountId':other,'username':'operator','displayName':'Denied'})[0]!=403:
                raise ValueError('User write accepted')
            passed(name+'-real-provider-'+method+'-'+path.strip('/')+'-denied')
    if request('GET','/account/',tokens['id_token'])[0]!=401: raise ValueError('ID token accepted by API')
    passed(name+'-real-provider-id-token-api-denied')


def database_fingerprint(runtime):
    query="SELECT json_build_object('accounts',(SELECT json_agg(t ORDER BY id) FROM accounts t),'memberships',(SELECT json_agg(t ORDER BY accountid,username) FROM accountusers t),'sequence',(SELECT json_build_object('value',last_value,'called',is_called) FROM accounts_seq));"
    value=run_compose(runtime,runtime/'account-dev','exec','-T','database','psql','-U','postgres','-d','accountdev','-At','-v','ON_ERROR_STOP=1','-c',query)
    return hashlib.sha256(value.encode()).hexdigest()
