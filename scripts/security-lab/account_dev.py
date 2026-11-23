#!/usr/bin/env python3
"""Render/manage a bounded three-container account development environment."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import time
import urllib.request
import urllib.error
import zipfile
from resource_operation import operation

ROOT = Path(__file__).resolve().parents[2]
PROFILE = ROOT/'specs/012-platform-convergence-c3/security-lab'
INPUTS = PROFILE/'generation/account-dev'
PROJECT = 'traderx-account-dev'
NODE = 'docker.io/library/node@sha256:a34ab6d7f6f4813f4d0c5469d74685604b962fbdbf5793a7bc7b4998ecb867c8'
URL = 'http://127.0.0.1:18488'


def compose(folder, pins, candidate=False):
    common = {'read_only': True, 'cap_drop':['ALL'], 'security_opt':['no-new-privileges:true'],
              'restart':'no', 'pull_policy':'always', 'pids_limit':128, 'cpus':1,
              'labels':{'traderx.security-lab.account-dev':'true'},
              'logging':{'driver':'json-file','options':{'max-size':'5m','max-file':'2'}}}
    def service(image, user, memory):
        return dict(common, image=image, user=user, mem_limit=memory, memswap_limit=memory)
    db = service(pins['traderx-remediation/postgres:012'], '70:70', '256m')
    db.update(platform='linux/amd64', environment={'POSTGRES_DB':'accountdev', 'POSTGRES_USER':'postgres',
        'POSTGRES_PASSWORD_FILE':'/run/private/bootstrap', 'POSTGRES_INITDB_ARGS':'--auth-host=scram-sha-256'},
        volumes=[f'{folder}/database:/run/private:ro', f'{folder}/init:/docker-entrypoint-initdb.d:ro'],
        tmpfs=['/var/lib/postgresql/data:uid=70,gid=70,mode=0700,size=134217728', '/var/run/postgresql:uid=70,gid=70,mode=0770,size=1048576', '/tmp:size=16777216'],
        healthcheck={'test':['CMD-SHELL','pg_isready -U postgres -d accountdev'], 'interval':'2s','timeout':'2s','retries':60})
    people = service(NODE, '1000:1000', '96m')
    people.update(platform='linux/arm64', command=['node','/lab/people-stub.js'], volumes=[f'{folder}/people-stub.js:/lab/people-stub.js:ro'])
    account = service(pins['traderx/account-service:state009'], '10001:10001', '512m')
    account.update(platform='linux/amd64', ports=['127.0.0.1:18488:18088'],
        environment={'DATABASE_PG_HOST':'database','DATABASE_PG_PORT':'5432','DATABASE_NAME':'accountdev',
            'SPRING_CONFIG_IMPORT':'configtree:/run/credentials/', 'PEOPLE_SERVICE_URL':'http://people:18089',
            'JAVA_TOOL_OPTIONS':'-Xms32m -Xmx192m -XX:ActiveProcessorCount=2',
            'SPRING_DATASOURCE_HIKARI_MAXIMUM_POOL_SIZE':'3', 'OTEL_SDK_DISABLED':'true',
            'OTEL_TRACES_EXPORTER':'none','OTEL_METRICS_EXPORTER':'none','OTEL_LOGS_EXPORTER':'none'},
        volumes=[f'{folder}/account:/run/credentials:ro'], tmpfs=['/tmp:uid=10001,gid=10001,size=67108864'],
        depends_on={'database':{'condition':'service_healthy'}, 'people':{'condition':'service_started'}})
    if candidate: account['volumes'].append(f'{folder}/candidate.jar:/opt/app/app.jar:ro')
    return {'name':PROJECT, 'services':{'database':db, 'people':people, 'account':account}}


def render(folder, jar=None, identity=None):
    if identity and not jar: raise ValueError('Identity configuration requires a security candidate jar')
    # Existing credentials/data must not be silently replaced.
    folder.mkdir(mode=0o700, parents=True, exist_ok=False)
    os.chmod(folder, 0o700)
    for name in ('database','account','init'): (folder/name).mkdir(mode=0o755)
    def write(name, data):
        path=folder/name; path.write_text(data); path.chmod(0o644)
    password=secrets.token_hex(32)
    write('database/bootstrap', secrets.token_hex(32))
    write('account/spring.datasource.username','lab_account')
    write('account/spring.datasource.password',password)
    write('init/01-account.sql',(INPUTS/'schema.sql').read_text().replace('__RUNTIME_PASSWORD__',password))
    shutil.copyfile(INPUTS/'people-stub.js',folder/'people-stub.js'); (folder/'people-stub.js').chmod(0o644)
    if jar:
        with zipfile.ZipFile(jar) as archive:
            if 'BOOT-INF/classes/finos/traderx/accountservice/AccountServiceApplication.class' not in archive.namelist():
                raise ValueError('Expected an account-service Spring bootJar')
            if identity and 'BOOT-INF/classes/finos/traderx/accountservice/security/AccountSecurity.class' not in archive.namelist():
                raise ValueError('Expected the protected account-service candidate')
        shutil.copyfile(jar,folder/'candidate.jar'); (folder/'candidate.jar').chmod(0o644)
    if identity:
        for name in ('public.pem','entitlements.properties'):
            write('account/'+name,(identity/name).read_text())
        for name in ('issuer','audience','key-not-after'):
            write('account/lab.identity.'+name,(identity/name).read_text())
        write('account/lab.identity.public-key-file','/run/credentials/public.pem')
        write('account/lab.identity.entitlements-file','/run/credentials/entitlements.properties')
    pins=json.loads((PROFILE/'baseline.lock.json').read_text())['image_digests']
    config=compose(folder.resolve(),pins,bool(jar))
    (folder/'compose.json').write_text(json.dumps(config,indent=2)+'\n')
    hashes={str(path.relative_to(folder)):hashlib.sha256(path.read_bytes()).hexdigest() for path in folder.rglob('*') if path.is_file()}
    (folder/'manifest.json').write_text(json.dumps({'files':hashes,'candidate_jar':bool(jar),'identity_configured':bool(identity)},indent=2)+'\n')
    return config


def verify_files(folder):
    manifest=json.loads((folder/'manifest.json').read_text())
    for name,digest in manifest['files'].items():
        if hashlib.sha256((folder/name).read_bytes()).hexdigest()!=digest:
            raise ValueError('Development input drift: render into a fresh directory')


def docker(runtime):
    return ['docker','--config',str(runtime/'docker-client'),'--host','unix://'+str(Path.home()/'.docker/run/docker.sock')]


def run_compose(runtime, folder, *args):
    verify_files(folder)
    try:
        return subprocess.run(docker(runtime)+['compose','-p',PROJECT,'-f',str(folder/'compose.json'),*args],
                              check=True,capture_output=True,text=True,timeout=300).stdout
    except subprocess.CalledProcessError as error:
        log=folder/'last-compose-error.log'; log.write_text(error.stderr); log.chmod(0o600)
        raise RuntimeError('Compose failed; private diagnostics: '+str(log)) from error


def check_ownership(runtime):
    # Refuse same-project containers that were not created by this recipe.
    ids=subprocess.run(docker(runtime)+['ps','-aq','--filter','label=com.docker.compose.project='+PROJECT],
                       check=True,capture_output=True,text=True,timeout=15).stdout.split()
    if ids:
        items=json.loads(subprocess.run(docker(runtime)+['inspect',*ids],check=True,capture_output=True,text=True,timeout=15).stdout)
        if any(x['Config'].get('Labels',{}).get('traderx.security-lab.account-dev')!='true' for x in items):
            raise ValueError('Unrelated Compose project collision')
        expected=str((runtime/'account-dev/compose.json').resolve())
        if any(x['Config'].get('Labels',{}).get('com.docker.compose.project.config_files')!=expected for x in items):
            raise ValueError('Compose project belongs to another runtime directory')


def start_services(runtime, folder):
    # Retain each pinned image in a container before pulling the next one.
    # Parallel pulls exposed local cache eviction between pull and create.
    for service in ('database', 'people', 'account'):
        run_compose(runtime, folder, 'up', '--no-start', '--no-deps', service)
    run_compose(runtime, folder, 'up', '-d', '--pull', 'never')


def probe(method, path, body=None):
    opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
    req=urllib.request.Request(URL+path,method=method,data=None if body is None else json.dumps(body).encode(),headers={'Content-Type':'application/json'})
    try:
        with opener.open(req,timeout=5) as response: return response.status,json.load(response)
    except urllib.error.HTTPError as error: return error.code,None


def wait_seed():
    deadline=time.monotonic()+180
    while True:
        try:
            status, accounts=probe('GET','/account/')
            if status==200: break
        except (OSError,urllib.error.URLError): pass
        if time.monotonic()>deadline: raise TimeoutError('Account development readiness')
        time.sleep(1)
    if {x['id'] for x in accounts}!={22214,62654}: raise ValueError('Expected fresh synthetic seed')
    return accounts


def smoke():
    wait_seed()
    checks=[]
    def expect(name, condition):
        if not condition: raise ValueError('Development smoke failed: '+name)
        checks.append(name)
    expect('seeded-account-read', probe('GET','/account/22214')[0]==200)
    expect('membership-account-id-semantics', probe('GET','/accountuser/22214')[1]['accountId']==22214)
    status,created=probe('POST','/account/',{'displayName':'Synthetic temporary account'})
    expect('account-create',status==200 and created['id']>=70000)
    expect('account-update',probe('PUT','/account/',{'id':created['id'],'displayName':'Synthetic changed account'})[0]==200)
    expect('people-stub-positive',probe('POST','/accountuser/',{'accountId':created['id'],'username':'operator'})[0]==200)
    expect('unknown-person-denied',probe('POST','/accountuser/',{'accountId':created['id'],'username':'unknown'})[0]==404)
    expect('no-invalid-membership',all(x['username']!='unknown' for x in probe('GET','/accountuser/')[1]))
    expect('missing-account',probe('GET','/account/999999')[0]==404)
    return checks


def reset_check(runtime, folder):
    output=runtime/'evidence/account-development.json'
    output.parent.mkdir(exist_ok=True)
    record={'status':'running','started_at':datetime.now(timezone.utc).isoformat(),
            'scope':'minimal-account-development-not-security-acceptance','cycles':[],
            'limitations':['People service is a fixed stub; no user authorization is implemented.',
                           'Memory readings are samples, not continuous startup peaks.',
                           'Container recreation previously failed with a missing Node image after image deletions. Reset now retains containers/image references and clears tmpfs through stop/start.']}
    def save(): output.write_text(json.dumps(record,indent=2)+'\n')
    save()
    try:
        for cycle in range(2):
            run_compose(runtime,folder,'stop')
            run_compose(runtime,folder,'start')
            checks=smoke()
            rows=subprocess.run(docker(runtime)+['stats','--no-stream','--format','{{json .}}'],check=True,capture_output=True,text=True,timeout=15).stdout.splitlines()
            samples=[json.loads(row) for row in rows if 'traderx-account-dev-' in row]
            record['cycles'].append({'cycle':cycle+1,'checks':checks,'memory_samples':[{'name':x['Name'],'memory':x['MemUsage']} for x in samples]})
            save(); print('Development cycle '+str(cycle+1)+': eight checks passed.',flush=True)
        run_compose(runtime,folder,'stop'); run_compose(runtime,folder,'start'); wait_seed()
        ids=subprocess.run(docker(runtime)+['ps','-q','--filter','label=com.docker.compose.project='+PROJECT],check=True,capture_output=True,text=True,timeout=15).stdout.split()
        objects=json.loads(subprocess.run(docker(runtime)+['inspect',*ids],check=True,capture_output=True,text=True,timeout=15).stdout)
        if len(objects)!=3: raise ValueError('Expected three development containers')
        for item in objects:
            host=item['HostConfig']
            if item['Config']['User'] not in ('70:70','1000:1000','10001:10001') or not host['ReadonlyRootfs'] or host['CapDrop']!=['ALL']:
                raise ValueError('Development workload restrictions mismatch')
            if host['Memory']!=host['MemorySwap'] or host['Memory'] not in (96*1024**2,256*1024**2,512*1024**2):
                raise ValueError('Development memory limits mismatch')
            if any(b['HostIp']!='127.0.0.1' for values in (host['PortBindings'] or {}).values() for b in values):
                raise ValueError('Unexpected exposed interface')
            if any(str(folder)+'/' not in m['Source'] for m in item['Mounts'] if m['Type']=='bind'):
                raise ValueError('Unexpected development bind mount')
        connections=run_compose(runtime,folder,'exec','-T','database','psql','-U','postgres','-d','accountdev','-At','-c',"select count(*) from pg_stat_activity where datname='accountdev' and usename='lab_account';")
        if int(connections.strip())<1: raise ValueError('Application SQL identity not observed')
        record.update(status='passed',clean_seed_restored=True,container_restrictions_verified=True,
                      application_sql_identity='lab_account',images={x['Name']:x['Config']['Image'] for x in objects})
    except BaseException as error:
        record.update(status='failed',failure_type=type(error).__name__); raise
    finally:
        record['finished_at']=datetime.now(timezone.utc).isoformat()
        record['source_sha256']={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [Path(__file__).resolve(),INPUTS/'schema.sql',INPUTS/'people-stub.js']}
        save()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=['render','up','down','verify','verify-reset'])
    parser.add_argument('--runtime-dir',type=Path,default=Path('/private/tmp/traderx-security-runtime'))
    parser.add_argument('--jar',type=Path,help='Optional locally built account bootJar; copied and hashed at render time')
    parser.add_argument('--identity-config',type=Path,help='Public trust and entitlement directory for a protected candidate')
    args=parser.parse_args(); runtime=args.runtime_dir.resolve(); folder=runtime/'account-dev'
    os.umask(0o077)
    if args.action=='render':
        render(folder,args.jar,args.identity_config); print('Rendered private account development inputs.'); return
    if args.jar or args.identity_config: parser.error('Candidate/config arguments are accepted only with render')
    # Cleanup must remain possible during pressure. It still uses the shared lock.
    from resource_operation import operation_lock
    with operation_lock(runtime):
        check_ownership(runtime)
        if args.action=='down':
            run_compose(runtime,folder,'down'); print('Removed disposable development containers.'); return
        from resource_preflight import require
        require(runtime,'development')
        if args.action=='up':
            start_services(runtime,folder); print('Account development endpoint: '+URL); return
        if args.action=='verify-reset':
            reset_check(runtime,folder); print('Reset verification passed; clean development environment running.'); return
        print(json.dumps({'status':'passed','scope':'account-development-only','checks':smoke()},indent=2))


if __name__=='__main__': main()
