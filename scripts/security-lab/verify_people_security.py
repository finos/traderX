"""Live generated .NET directory authorization with real Keycloak tokens."""
import argparse
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import time
import urllib.error
import urllib.request

from cryptography.hazmat.primitives import serialization
from browser_session import BrowserServer, ORIGIN, SESSION
from identity_fixture import AUDIENCE, ISSUER, SUBJECTS, TokenVerifier
from resource_operation import operation
from verify_browser_api import Browser, provider


@contextmanager
def directory(target, private, jwks, *, audience=AUDIENCE, issuer=ISSUER, lifetime=300):
    dll=target/'PeopleService.WebApi/bin/Release/net9.0/PeopleService.WebApi.dll'
    if not dll.is_file():raise ValueError('Build the generated people candidate first')
    manifest=json.loads((target/'security-generation.json').read_text())
    root=Path(__file__).resolve().parents[2]
    for mapping,base in ((manifest['inputs'],root),(manifest['files'],target)):
        for name,digest in mapping.items():
            if hashlib.sha256((base/name).read_bytes()).hexdigest()!=digest:raise ValueError('People candidate source drift')
    keys=TokenVerifier(jwks).keys
    if len(keys)!=1:raise ValueError('Expected one signing key')
    public=private/'public.pem';public.write_bytes(next(iter(keys.values())).public_bytes(serialization.Encoding.PEM,serialization.PublicFormat.SubjectPublicKeyInfo))
    roles=private/'roles.json';roles.write_text(json.dumps({'lab-reader':'read-only','lab-trader':'trader','lab-operator':'operator'}))
    with socket.socket() as probe:probe.bind(('127.0.0.1',0));port=probe.getsockname()[1]
    until=time.time()+lifetime
    env=dict(os.environ,LAB_PEOPLE_LOOPBACK_PORT=str(port),LAB_IDENTITY_ISSUER=issuer,
        LAB_IDENTITY_AUDIENCE=audience,LAB_IDENTITY_PUBLIC_KEY_FILE=str(public),
        LAB_IDENTITY_KEY_NOT_AFTER=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime(until)),
        LAB_IDENTITY_DIRECTORY_ROLES_FILE=str(roles),PeopleJsonFilePath=str(target/'PeopleService.WebApi/MockDirectory/people.json'),
        DOTNET_GCHeapHardLimit='10000000',DOTNET_PROCESSOR_COUNT='2',DOTNET_gcServer='0')
    origin=f'http://127.0.0.1:{port}';opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
    def call(path,bearer=None,method='GET',headers=None):
        values={} if bearer is None else {'Authorization':'Bearer '+bearer}
        values.update(headers or {})
        req=urllib.request.Request(origin+path,headers=values,method=method)
        try:response=opener.open(req,timeout=10)
        except urllib.error.HTTPError as error:response=error
        with response:return response.code,dict(response.headers),response.read()
    dotnet=shutil.which('dotnet')
    if not dotnet:raise ValueError('The hosted .NET SDK is required')
    with (private/'people-private.log').open('a') as log:
        child=subprocess.Popen([dotnet,str(dll)],cwd=target/'PeopleService.WebApi',env=env,stdout=log,stderr=subprocess.STDOUT)
    try:
        deadline=time.monotonic()+45
        while True:
            if child.poll() is not None:raise RuntimeError('People process exited; private log withheld')
            try:
                if call('/health/alive')[0]==200:break
            except OSError:pass
            if time.monotonic()>deadline:raise RuntimeError('People readiness timed out')
            time.sleep(.25)
        yield call,until
    finally:
        if child.poll() is None:
            child.terminate()
            try:child.wait(timeout=10)
            except subprocess.TimeoutExpired:child.kill();child.wait(timeout=5)


def campaign(runtime):
    if not __debug__:raise RuntimeError('Assertions required')
    checks=[]
    def check(name,value):
        if not value:raise AssertionError(name)
        checks.append(name);print(name+': passed',flush=True)
    target=runtime/'people-service'
    data=target/'PeopleService.WebApi/MockDirectory/people.json'
    before=hashlib.sha256(data.read_bytes()).hexdigest()
    paths=['/People/GetPerson?logonId=user01','/People/GetMatchingPeople?searchText=Alice&take=1','/People/ValidatePerson?employeeId=E0001']
    with tempfile.TemporaryDirectory(prefix='people-identity-',dir=runtime) as temp:
        private=Path(temp)
        def conflicting_roles(config):
            # Deliberately give the reader a provider role that the API's private
            # business map does not grant; token roles must not confer access.
            next(user for user in config['users'] if user['username']=='reader')['realmRoles'].append('operator')
        with provider(runtime,private,configure=conflicting_roles) as (mount,context,jwks,passwords):
            server=BrowserServer(mount/'cert.pem',mount/'key.pem',context,jwks).start()
            try:
                tokens={}
                for name in SUBJECTS:
                    browser=Browser(context);browser.login(name,passwords[name])
                    cookie=next(c.value for c in browser.jar if c.name==SESSION)
                    # Fixture reads the server-owned token; it is never returned to browser JS/evidence.
                    with server.store.lock:tokens[name]=server.store.sessions[cookie]['token']
                with directory(target,private,jwks) as (call,_):
                    for path in paths:
                        check('anonymous '+path.split('?')[0]+' denied',call(path)[0]==401)
                        for name in ('reader','trader'):
                            status,_,body=call(path,tokens[name],headers={'X-Role':'operator','X-Account-Id':'22214'})
                            check(name+' '+path.split('?')[0]+' denied without directory data',status==403 and b'user01' not in body and b'Alice' not in body)
                        status,headers,body=call(path,tokens['operator'])
                        check('operator '+path.split('?')[0]+' allowed',status==200)
                        check('directory response has no CORS grant and no cache',headers.get('Access-Control-Allow-Origin') is None and headers.get('Cache-Control')=='no-store')
                    status,_,body=call(paths[0],tokens['operator']);person=json.loads(body)
                    check('operator receives expected synthetic person',status==200 and person['logonId']=='user01')
                    for path in ('/swagger/index.html','/People/GetPerson/','/people/GetPerson','/metrics'):
                        check('unapproved route '+path+' unavailable',call(path,tokens['operator'])[0]==404)
                    check('directory mutations unavailable',call('/People/GetPerson',tokens['operator'],method='POST')[0]==404)
                    for path in ('/People/GetMatchingPeople?searchText=Alice&take=9999','/People/GetMatchingPeople?searchText=Al','/People/GetPerson?logonId=user01&employeeId=E0001'):
                        check('bounded query '+path.split('?')[0]+' rejected',call(path,tokens['operator'])[0]==400)
                    forged=tokens['operator'].split('.');forged[2]=('A' if forged[2][0]!='A' else 'B')+forged[2][1:]
                    check('wrong signature rejected',call(paths[0],'.'.join(forged))[0]==401)
                for label,kwargs in (('audience',{'audience':'different-api'}),('issuer',{'issuer':'https://wrong.example.invalid'})):
                    with directory(target,private,jwks,**kwargs) as (call,_):
                        check('wrong '+label+' rejected',call(paths[0],tokens['operator'])[0]==401)
                with directory(target,private,jwks,lifetime=6) as (call,until):
                    check('valid identity before trust expiry allowed',call(paths[0],tokens['operator'])[0]==200)
                    time.sleep(max(0,until-time.time())+.1)
                    check('expired trust snapshot denied',call(paths[0],tokens['operator'])[0]==401)
                check('directory bytes unchanged',hashlib.sha256(data.read_bytes()).hexdigest()==before)
            finally:server.close()
    return {'status':'passed','scope':'Live Keycloak and generated .NET operator-only people API; not deployed',
        'checks':checks,'directory_sha256':before,
        'assembly_sha256':hashlib.sha256((target/'PeopleService.WebApi/bin/Release/net9.0/PeopleService.WebApi.dll').read_bytes()).hexdigest(),
        'limitations':['Provider/browser TLS verified; people HTTP is explicit loopback fixture transport',
            'Directory operator role comes from private startup map; live entitlement reload and subject/person binding are not implemented',
            'People routes remain outside the public browser API allowlist; account membership mutations remain disabled']}


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--runtime-dir',required=True,type=Path);parser.add_argument('--output',required=True,type=Path)
    args=parser.parse_args();os.umask(0o077)
    if args.output.exists():raise ValueError('Evidence already exists')
    with operation(args.runtime_dir,'fixture'):result=campaign(args.runtime_dir)
    with args.output.open('x') as output:json.dump(result,output,indent=2);output.write('\n')
    print(json.dumps(result,sort_keys=True))


if __name__=='__main__':main()
