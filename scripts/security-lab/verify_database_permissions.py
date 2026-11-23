#!/usr/bin/env python3
"""Verify real SQL logins, exact grants and rollback-only synthetic operations."""
import argparse
import base64
import copy
from datetime import datetime,timezone
import hashlib
import json
from pathlib import Path
import subprocess
import uuid
import database_permissions as db
from database_rotation import public_result


def sql_login(k,role,password,sql):
    # Password travels only over stdin, never process arguments, evidence or logs.
    shell='IFS= read -r PGPASSWORD; export PGPASSWORD; exec psql -X -w -h database -U "$1" -d traderx -At -v ON_ERROR_STOP=1 -v VERBOSITY=sqlstate'
    return subprocess.run(k+['-n',db.NS,'exec','-i','deployment/database','--','sh','-c',shell,'lab-sql',role],input=password+'\n'+sql+'\n',text=True,capture_output=True,timeout=45)


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--runtime-dir',type=Path,default=Path('/private/tmp/traderx-security-runtime'));p.add_argument('--output-dir',type=Path,required=True);a=p.parse_args();root=a.runtime_dir.resolve();k=['kubectl','--kubeconfig',str(root/'kubeconfig')]
    def run(*cmd,doc=None,check=True):return subprocess.run(k+list(cmd),input=json.dumps(doc) if doc else None,text=True,capture_output=True,check=check,timeout=45)
    assert run('config','current-context').stdout.strip()=='kind-traderx-security-lab'
    assert [n['metadata']['name'] for n in json.loads(run('get','nodes','-o','json').stdout)['items']]==['traderx-security-lab-control-plane']
    state=json.loads((root/'database-permissions/state.json').read_text());assert state['complete']
    assert hashlib.sha256((root/'database-permissions/database.dump').read_bytes()).hexdigest()==state['backup_sha256']
    reference=json.loads((root/'reference.json').read_text());expected=db.deployments(reference)
    for d in db.admission(reference):
        live=json.loads(run('get',d['kind'],d['metadata']['name'],'-o','json').stdout)
        if d['kind']=='ValidatingAdmissionPolicy':
            for key in ['validations','matchConditions','failurePolicy']:assert live['spec'][key]==d['spec'][key]
            assert not live.get('status',{}).get('typeChecking',{}).get('expressionWarnings'),live.get('status')
        else:assert live['spec']==d['spec']
    results=[];admission=[]
    for d in expected:
        name=d['metadata']['name'];grant=db.GRANTS[name];role=grant['role']
        live=json.loads(run('-n',db.NS,'get','deployment',name,'-o','json').stdout)
        assert live['status'].get('availableReplicas')==1 and live['status']['observedGeneration']==live['metadata']['generation']
        assert live['spec']['template']['spec']['containers'][0]['env']==d['spec']['template']['spec']['containers'][0]['env']
        secret=json.loads(run('-n',db.NS,'get','secret',db.secret_name(name),'-o','json').stdout)
        assert not secret['metadata'].get('annotations',{}).get('kubectl.kubernetes.io/last-applied-configuration')
        username=base64.b64decode(secret['data']['username']).decode();password=base64.b64decode(secret['data']['password']).decode();assert username==role
        def allowed(sql):
            result=sql_login(k,role,password,sql);assert result.returncode==0,(name,'SQL positive control failed',result.stderr);return result.stdout.strip()
        assert allowed('SELECT current_user;')==role
        flags=allowed("SELECT rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls FROM pg_roles WHERE rolname=current_user;")
        assert flags=='f'
        assert allowed('SELECT count(*) FROM pg_auth_members WHERE member=(SELECT oid FROM pg_roles WHERE rolname=current_user);')=='0'
        assert allowed("SELECT count(*) FROM pg_class WHERE relnamespace='public'::regnamespace AND relowner=(SELECT oid FROM pg_roles WHERE rolname=current_user);")=='0'
        assert allowed("SELECT has_schema_privilege(current_user,'public','USAGE'),has_schema_privilege(current_user,'public','CREATE'),has_database_privilege(current_user,'traderx','CONNECT'),has_database_privilege(current_user,'traderx','CREATE'),has_database_privilege(current_user,'traderx','TEMP');")=='t|f|t|f|f'
        checks=[]
        for table in ['accounts','accountusers','positions','trades','orderbook']:
            for verb in ['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']:
                yes=verb in grant['tables'].get(table,[])
                checks.append(f"SELECT '{table}:{verb}',has_table_privilege(current_user,'public.{table}','{verb}');")
        observed=dict(row.split('|') for row in allowed('\n'.join(checks)).splitlines())
        for key,value in observed.items():
            table,verb=key.split(':');assert (value=='t')==(verb in grant['tables'].get(table,[])),(name,key,value)
        assert allowed("SELECT has_sequence_privilege(current_user,'public.accounts_seq','USAGE'),has_sequence_privilege(current_user,'public.accounts_seq','UPDATE');")==('t|f' if name=='account-service' else 'f|f')
        token=uuid.uuid4().hex;account_id=-int(token[:6],16)-1;security='LAB'+token[:8]
        if name=='account-service':
            statements=f"INSERT INTO accounts VALUES ({account_id},'SQL rollback probe'); UPDATE accounts SET displayname='Updated probe' WHERE id={account_id}; INSERT INTO accountusers VALUES ({account_id},'lab_sql_probe'); SELECT nextval('accounts_seq');"
            canary=f'SELECT count(*) FROM accounts WHERE id={account_id};'
        elif name=='position-service':statements='SELECT count(*) FROM positions; SELECT count(*) FROM trades;';canary=None
        elif name=='trade-processor':
            statements=f"INSERT INTO trades(id,accountid,security,side,quantity,price,state) VALUES ('{token}',22214,'{security}','Buy',1,1,'New'); UPDATE trades SET state='Processing' WHERE id='{token}'; INSERT INTO positions(accountid,security,quantity,averagecostbasis) VALUES (22214,'{security}',1,1); UPDATE positions SET quantity=2 WHERE accountid=22214 AND security='{security}';"
            canary=f"SELECT (SELECT count(*) FROM trades WHERE id='{token}')+(SELECT count(*) FROM positions WHERE security='{security}');"
        else:
            statements=f"INSERT INTO orderbook(orderid,accountid,security,side,quantity,remainingquantity,limitprice,status,createdat,updatedat) VALUES ('{token}',22214,'{security}','Buy',1,1,1,'NEW',now(),now()); UPDATE orderbook SET status='CANCELED' WHERE orderid='{token}';"
            canary=f"SELECT count(*) FROM orderbook WHERE orderid='{token}';"
        allowed('BEGIN;\n'+statements+'\nROLLBACK;')
        if canary:assert run('-n',db.NS,'exec','deployment/database','--','psql','-U','traderx','-d','traderx','-Atc',canary).stdout.strip()=='0'
        table='positions' if name=='position-service' else next(iter(grant['tables']))
        forbidden={'schema-ddl':'CREATE TABLE public.lab_forbidden_'+token+' (id integer);','role-administration':'CREATE ROLE lab_forbidden_'+token+';','unrelated-read':'SELECT * FROM '+('positions' if name=='account-service' else 'accounts')+' LIMIT 0;','delete-outside-grants':'DELETE FROM '+table+' WHERE false;'}
        for case,sql in forbidden.items():
            result=sql_login(k,role,password,'BEGIN;\n'+sql+'\nROLLBACK;')
            assert result.returncode!=0 and '42501' in result.stderr,(name,case,'Expected SQL insufficient_privilege')
        # Real JDBC pools must be using the service role, not merely the verifier.
        sessions=run('-n',db.NS,'exec','deployment/database','--','psql','-U','traderx','-d','traderx','-Atc',f"SELECT count(*) FROM pg_stat_activity WHERE usename='{role}' AND application_name='PostgreSQL JDBC Driver';").stdout.strip()
        assert int(sessions)>0,(name,'No service-role JDBC sessions')
        run('apply','--dry-run=server','-f','-',doc=d)
        for case in ['literal-password','other-service-secret','extra-environment','runtime-ddl']:
            if case=='runtime-ddl' and name!='order-matcher':continue
            bad=copy.deepcopy(d);env=bad['spec']['template']['spec']['containers'][0]['env']
            if case=='literal-password':env[:]=[{'name':e['name'],'value':'demonstration-only'} if e['name']=='DATABASE_DBPASS' else e for e in env]
            elif case=='other-service-secret':next(e for e in env if e['name']=='DATABASE_DBPASS')['valueFrom']['secretKeyRef']['name']='unrelated-secret'
            elif case=='extra-environment':env.append({'name':'SPRING_DATASOURCE_USERNAME','value':'traderx'})
            else:next(e for e in env if e['name']=='SPRING_JPA_HIBERNATE_DDL_AUTO')['value']='update'
            reply=run('apply','--dry-run=server','-f','-',doc=bad,check=False)
            assert reply.returncode!=0 and db.POLICY in reply.stderr and 'SQL:' in reply.stderr,(name,case,reply.stderr)
            admission.append({'service':name,'case':case,'denied_by':db.POLICY})
        pod={'apiVersion':'v1','kind':'Pod','metadata':{'name':'sql-admission-'+uuid.uuid4().hex[:8],'namespace':db.NS,'labels':{'app':name}},'spec':copy.deepcopy(d['spec']['template']['spec'])}
        run('create','--dry-run=server','-f','-',doc=pod)
        next(e for e in pod['spec']['containers'][0]['env'] if e['name']=='DATABASE_DBPASS')['valueFrom']['secretKeyRef']['name']='lab-sql-bootstrap'
        reply=run('create','--dry-run=server','-f','-',doc=pod,check=False)
        assert reply.returncode!=0 and db.POLICY+'-pods' in reply.stderr and 'SQL:' in reply.stderr
        admission.append({'service':name,'case':'direct-pod-bootstrap-secret','denied_by':db.POLICY+'-pods'})
        results.append({'service':name,'role':role,'privileged_flags':False,'table_permissions_verified':35,'positive_transaction_rolled_back':True,'jdbc_sessions':int(sessions),'denied_operations':list(forbidden),'sqlstate':'42501'})
        print(name+': restricted real login, permitted transaction, 4 SQL denials and JDBC identity verified.',flush=True)
    assert state.get('bootstrap_rotated')
    bootstrap=json.loads(run('-n',db.NS,'get','secret','lab-sql-bootstrap','-o','json').stdout)
    bootstrap_password=base64.b64decode(bootstrap['data']['password']).decode()
    old_database=next(d for d in reference['items'] if d['kind']=='Deployment' and d['metadata']['name']=='database')
    old_password=next(e['value'] for e in old_database['spec']['template']['spec']['containers'][0]['env'] if e['name']=='POSTGRES_PASSWORD')
    rejected=sql_login(k,'traderx',old_password,'SELECT current_user;')
    assert rejected.returncode!=0 and ('28P01' in rejected.stderr or 'password authentication failed' in rejected.stderr)
    accepted=sql_login(k,'traderx',bootstrap_password,'SELECT current_user;');assert accepted.returncode==0 and accepted.stdout.strip()=='traderx'
    bootstrap_deployment=db.bootstrap_deployment(reference)
    current_database=json.loads(run('-n',db.NS,'get','deployment','database','-o','json').stdout)
    assert current_database['spec']['template']['spec']['containers'][0]['env']==bootstrap_deployment['spec']['template']['spec']['containers'][0]['env']
    run('apply','--dry-run=server','-f','-',doc=bootstrap_deployment)
    bad=copy.deepcopy(bootstrap_deployment)
    env=bad['spec']['template']['spec']['containers'][0]['env'];env[:]=[{'name':'POSTGRES_PASSWORD','value':'demonstration-only'} if e['name']=='POSTGRES_PASSWORD' else e for e in env]
    rejected=run('apply','--dry-run=server','-f','-',doc=bad,check=False)
    assert rejected.returncode!=0 and db.POLICY in rejected.stderr and 'SQL:' in rejected.stderr
    admission.append({'service':'database','case':'literal-bootstrap-password','denied_by':db.POLICY})
    old_sessions=run('-n',db.NS,'exec','deployment/database','--','psql','-U','traderx','-d','traderx','-Atc',"SELECT count(*) FROM pg_stat_activity WHERE usename='traderx' AND application_name='PostgreSQL JDBC Driver';").stdout.strip();assert old_sessions=='0'
    result={'scenario':'database-permissions','status':'passed','recorded_at':datetime.now(timezone.utc).isoformat(),'services':results,'admission_checks':admission,'legacy_admin_jdbc_sessions':0,'known_bootstrap_password_rejected':True,'bootstrap_secret_reference_verified':True,'limitations':['Service grants do not enforce initiating user/account permissions.','Each account positive control advances the sequence once; synthetic row writes are rolled back.','Bootstrap operator remains a separate privileged identity. Credential rotation is a separate acceptance step.'],'source_hashes':{n:hashlib.sha256((Path(__file__).parent/n).read_bytes()).hexdigest() for n in ['database_permissions.py','migrate-database-permissions.py','verify_database_permissions.py']}}
    rotation_path=root/'database-rotation/private-state.json'
    if rotation_path.exists():
        rotation=json.loads(rotation_path.read_text())
        if rotation['phase']=='complete':
            assert rotation['old_pod_uid']!=rotation['new_pod_uid'] and rotation['old_jdbc_sessions_drained']
            before={(r['pid'],r['started']) for r in rotation['sessions_before']};after={(r['pid'],r['started']) for r in rotation['sessions_after']}
            assert before and after and not before.intersection(after)
            old=sql_login(k,'lab_position',rotation['old_password'],'SELECT current_user;')
            assert old.returncode!=0 and ('28P01' in old.stderr or 'password authentication failed' in old.stderr)
            new=sql_login(k,'lab_position',rotation['new_password'],'SELECT current_user;');assert new.returncode==0 and new.stdout.strip()=='lab_position'
            smoke=root/'database-rotation/trading-smoke.log'
            assert hashlib.sha256(smoke.read_bytes()).hexdigest()==rotation['trading_smoke_sha256']
            result['rotation']=public_result(rotation)
            result['rotation']['retired_login_rechecked']=True
            result['limitations']=[x.replace('Credential rotation is a separate acceptance step.','Position-service runtime rotation verified; other identities have not been rotated in this exercise.') for x in result['limitations']]
            result['source_hashes'].update({n:hashlib.sha256((Path(__file__).parent/n).read_bytes()).hexdigest() for n in ['database_rotation.py','rotate-database-credential.py']})
    a.output_dir.mkdir(parents=True,exist_ok=True);(a.output_dir/'database-permissions-result.json').write_text(json.dumps(result,indent=2)+'\n');print('PASS: four scoped SQL identities; no application JDBC connection uses the bootstrap administrator.',flush=True)

if __name__=='__main__':main()
