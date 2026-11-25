#!/usr/bin/env python3
"""Exercise fresh SQL bootstrap twice in bounded, private, disposable PostgreSQL containers."""
import argparse
from contextlib import contextmanager
import hashlib
import json
from pathlib import Path
import secrets
import socket
import subprocess
import tempfile
import time
import uuid

import account_dev
import bootstrap_database as bootstrap
import database_permissions as db
from resource_operation import operation

TABLES = ('accounts', 'accountusers', 'positions', 'trades', 'orderbook')


def command(args, **kwargs):
    # Never surface stderr/SQL/private configuration in an exception or evidence.
    result = subprocess.run(args, capture_output=True, text=True, timeout=kwargs.pop('timeout',60), **kwargs)
    if result.returncode:
        raise RuntimeError('Database fixture command failed; no private output exported')
    return result.stdout.strip()


@contextmanager
def database(runtime, image, credentials=None, persistent=False, loopback=False):
    docker = account_dev.docker(runtime)
    run_id = uuid.uuid4().hex
    name = 'traderx-bootstrap-' + run_id[:12]
    label = 'traderx.security-lab.bootstrap'
    with tempfile.TemporaryDirectory(prefix='bootstrap-private-', dir=runtime) as temp:
        password = credentials['bootstrap']['password'] if credentials else secrets.token_hex(32)
        secret = Path(temp)/'bootstrap'
        # The 0700 parent protects host access; only this file is mounted into UID 70.
        secret.write_text(password); secret.chmod(0o644)
        container = None
        volume = None
        try:
            if subprocess.run(docker+['image','inspect',image],capture_output=True).returncode:
                command(docker+['pull','--platform','linux/amd64',image],timeout=240)
            data_mount = ['--tmpfs','/var/lib/postgresql/data:uid=70,gid=70,mode=0700,size=134217728']
            if persistent:
                volume = command(docker+['volume','create','--label',label+'='+run_id,name+'-data'])
                data_mount = ['--mount',f'type=volume,src={volume},dst=/var/lib/postgresql/data']
            loopback_port=None
            if loopback:
                with socket.socket() as probe:
                    probe.bind(('127.0.0.1',0));loopback_port=probe.getsockname()[1]
            container = command(docker+['create','--name',name,'--label',label+'='+run_id,
                '--network',('bridge' if loopback else 'none'),*(['--publish',f'127.0.0.1:{loopback_port}:5432'] if loopback else []),'--restart','no','--user','70:70','--read-only','--cap-drop','ALL',
                '--security-opt','no-new-privileges:true','--memory','256m','--memory-swap','256m',
                '--cpus','1','--pids-limit','128','--platform','linux/amd64',
                '--log-driver','local','--log-opt','max-size=5m','--log-opt','max-file=2',
                '--mount',f'type=bind,src={secret},dst=/run/bootstrap,readonly',
                *data_mount,
                '--tmpfs','/var/run/postgresql:uid=70,gid=70,mode=0770,size=1048576',
                '--tmpfs','/tmp:uid=70,gid=70,size=16777216',
                # Suppress image-baked reference seed scripts; our guarded SQL owns initialization.
                '--tmpfs','/docker-entrypoint-initdb.d:uid=70,gid=70,mode=0755,size=1048576',
                '-e','POSTGRES_DB=traderx','-e','POSTGRES_USER=traderx',
                '-e','POSTGRES_PASSWORD_FILE=/run/bootstrap',
                '-e','POSTGRES_INITDB_ARGS=--auth-host=scram-sha-256',
                image,'postgres','-c','log_statement=none','-c','log_min_error_statement=panic'])
            command(docker+['start',container])
            shell='IFS= read -r PGPASSWORD; export PGPASSWORD; exec psql -X -w -h 127.0.0.1 -U "$1" -d traderx -At -v ON_ERROR_STOP=1 -v VERBOSITY=sqlstate'
            def sql(role, credential, text):
                return subprocess.run(docker+['exec','-i',container,'sh','-c',shell,'lab-sql',role],
                    input=credential+'\n'+text+'\n',capture_output=True,text=True,timeout=45)
            def wait_ready():
                deadline=time.monotonic()+90
                while True:
                    ready=sql('traderx',password,'SELECT 1;')
                    if ready.returncode==0 and ready.stdout.strip()=='1':break
                    if time.monotonic()>deadline:raise RuntimeError('Database fixture readiness timed out')
                    time.sleep(.5)
            def restart():
                command(docker+['stop','--time','20',container])
                command(docker+['start',container])
                wait_ready()
            wait_ready()
            if loopback:
                endpoint=command(docker+['port',container,'5432/tcp'])
                if not endpoint.startswith('127.0.0.1:') or not endpoint.removeprefix('127.0.0.1:').isdigit():
                    raise RuntimeError('Unexpected database publication')
                yield sql,password,restart,int(endpoint.split(':')[1])
            else:
                yield (sql, password, restart) if persistent else (sql, password)
        finally:
            if container:
                owner=command(docker+['inspect','--format','{{index .Config.Labels "'+label+'"}}',container])
                if owner!=run_id:raise RuntimeError('Refusing cleanup of a container not owned by this run')
                command(docker+['rm','-f',container])
            if volume:
                owner=command(docker+['volume','inspect','--format','{{index .Labels \"'+label+'\"}}',volume])
                if owner!=run_id:raise RuntimeError('Refusing cleanup of unowned fixture volume')
                command(docker+['volume','rm',volume])


def require(result, message):
    if result.returncode:raise RuntimeError(message + ' (SQL details withheld)')
    return result.stdout.strip()


def denied(result, code, message):
    if result.returncode==0 or code not in result.stderr:
        raise RuntimeError(message)


def fingerprint(sql, password):
    rows={}
    for table in TABLES:
        text=f"SELECT count(*),COALESCE(md5(string_agg(x::text,'' ORDER BY x::text)),'empty') FROM (SELECT to_jsonb(t) x FROM {table} t) s;"
        rows[table]=require(sql('traderx',password,text),'Seed fingerprint failed')
    return rows


def campaign(runtime):
    reference=bootstrap.pinned_reference()
    image=next(d for d in reference['items'] if d['kind']=='Deployment' and d['metadata']['name']=='database')['spec']['template']['spec']['containers'][0]['image']
    rounds=[]
    for round_id in range(2):
        identities=bootstrap.credentials()
        with database(runtime,image) as (sql,password):
            if round_id==0:
                require(sql('traderx',password,'CREATE SCHEMA existing_data; CREATE TABLE existing_data.canary(id int); INSERT INTO existing_data.canary VALUES(19);'),'Prepare existing-data canary')
                denied(sql('traderx',password,bootstrap.render(reference,identities)),'P0001','Existing user schema was not refused')
                if require(sql('traderx',password,'SELECT id FROM existing_data.canary;'),'Read existing canary')!='19':
                    raise RuntimeError('Bootstrap changed preexisting canary')
                require(sql('traderx',password,'DROP SCHEMA existing_data CASCADE;'),'Remove fixture-owned canary')
            # A failed bootstrap rolls back schema, seed and roles together.
            if round_id==0:
                broken=bootstrap.render(reference,identities).replace('COMMIT;', 'SELECT 1/0;\nCOMMIT;')
                denied(sql('traderx',password,broken),'22012','Expected injected transaction failure')
                empty=require(sql('traderx',password,"SELECT (SELECT count(*) FROM pg_class WHERE relnamespace='public'::regnamespace)+(SELECT count(*) FROM pg_roles WHERE rolname LIKE 'lab_%');"),'Rollback inspection failed')
                if empty!='0':raise RuntimeError('Failed bootstrap left objects behind')
            require(sql('traderx',password,bootstrap.render(reference,identities)),'Fresh bootstrap failed')
            baseline=fingerprint(sql,password)
            counts={t:int(value.split('|')[0]) for t,value in baseline.items()}
            if counts!={'accounts':7,'accountusers':18,'positions':4,'trades':4,'orderbook':0}:
                raise RuntimeError('Seed counts differ from pinned fixture')
            checks=0
            for name,identity in identities.items():
                role=identity['username'];credential=identity['password'];grant=db.GRANTS[name]
                def allowed(text):return require(sql(role,credential,text),'Runtime role operation failed: '+name)
                if allowed('SELECT current_user;')!=role:raise RuntimeError('Incorrect runtime identity')
                flags=allowed("SELECT rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls FROM pg_roles WHERE rolname=current_user;")
                if flags!='f':raise RuntimeError('Administrative runtime role')
                for table in TABLES:
                    for verb in ('SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER'):
                        actual=allowed(f"SELECT has_table_privilege(current_user,'public.{table}','{verb}');")
                        if (actual=='t')!=(verb in grant['tables'].get(table,[])):raise RuntimeError('Unexpected table privilege')
                        checks+=1
                if allowed("SELECT has_schema_privilege(current_user,'public','CREATE'),has_database_privilege(current_user,'traderx','TEMP');")!='f|f':
                    raise RuntimeError('Unexpected schema/temp authority')
                positive={'account-service':"INSERT INTO accounts VALUES(-190019,'Bootstrap probe'); INSERT INTO accountusers VALUES(-190019,'probe'); UPDATE accounts SET displayname='Updated' WHERE id=-190019;",
                    'position-service':'SELECT count(*) FROM positions; SELECT count(*) FROM trades;',
                    'trade-processor':"INSERT INTO trades(id,accountid,security,side,quantity,price,state) VALUES('bootstrap-probe',22214,'IBM','Buy',1,1,'New'); UPDATE trades SET state='Processing' WHERE id='bootstrap-probe'; INSERT INTO positions VALUES(22214,'LAB',NULL,1,1); UPDATE positions SET quantity=2 WHERE security='LAB';",
                    'order-matcher':"INSERT INTO orderbook(orderid,accountid,security,side,quantity,remainingquantity,limitprice,status,createdat,updatedat) VALUES('bootstrap-probe',22214,'IBM','Buy',1,1,1,'NEW',now(),now()); UPDATE orderbook SET status='CANCELED' WHERE orderid='bootstrap-probe';"}[name]
                allowed('BEGIN;\n'+positive+'\nROLLBACK;');checks+=1
                for bad in ('CREATE ROLE forbidden;', 'CREATE TABLE public.forbidden(id int);', 'DELETE FROM '+next(iter(grant['tables']))+' WHERE false;'):
                    denied(sql(role,credential,'BEGIN;\n'+bad+'\nROLLBACK;'),'42501','Expected insufficient privilege');checks+=1
            # A repeated call with NEW passwords must refuse before changing either data or roles.
            denied(sql('traderx',password,bootstrap.render(reference,bootstrap.credentials())),'P0001','Existing database was not refused')
            for identity in identities.values():
                require(sql(identity['username'],identity['password'],'SELECT 1;'),'Retry changed credentials')
            if fingerprint(sql,password)!=baseline:raise RuntimeError('Checks or rejected retry changed seed rows')
            rounds.append({'round':round_id+1,'counts':counts,'fingerprints':baseline,'privilege_and_operation_checks':checks,
                'repeat_bootstrap':'refused-with-data-and-original-credentials-preserved'})
    if rounds[0]['fingerprints']!=rounds[1]['fingerprints']:raise RuntimeError('Independent fresh seeds differ')
    return {'status':'passed','scope':'two disposable PostgreSQL instances; no application or Kubernetes deployment',
        'image':image,'rounds':rounds,'injected_failure':'transaction rolled back objects and roles before clean retry',
        'limits':{'memory':'256Mi','cpu':1,'host_ports':0},
        'limitations':['Local database fixture only; full trading and cluster lifecycle remain pending.',
            'Fresh bootstrap refuses existing data; it is not a migration or reset.',
            'Privileges are service-level; user/business authorization remains a separate boundary.']}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-dir',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    if args.output.exists():raise ValueError('Evidence output already exists')
    with operation(args.runtime_dir,'fixture'):
        result=campaign(args.runtime_dir)
        args.output.write_text(json.dumps(result,indent=2)+'\n')
    print('Fresh bootstrap, rollback, scoped SQL and repeat refusal verified in two disposable instances.')


if __name__=='__main__':main()
