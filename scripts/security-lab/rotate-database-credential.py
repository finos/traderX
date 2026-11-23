#!/usr/bin/env python3
"""Rotate the position-service SQL credential and verify pooled-session replacement."""
import argparse
import base64
from datetime import datetime,timezone
import fcntl
import hashlib
import json
import os
from pathlib import Path
import secrets
import re
from database_rotation import public_result
import subprocess
import time
from verify_database_permissions import sql_login
import database_permissions as db

NAME='position-service';ROLE=db.GRANTS[NAME]['role']

def rejected(reply):return reply.returncode!=0 and ('28P01' in reply.stderr or 'password authentication failed' in reply.stderr)

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--runtime-dir',type=Path,default=Path('/private/tmp/traderx-security-runtime'));p.add_argument('--resume',action='store_true');a=p.parse_args();os.umask(0o077);root=a.runtime_dir.resolve();k=['kubectl','--kubeconfig',str(root/'kubeconfig')]
    def run(*cmd,doc=None,timeout=60):return subprocess.run(k+list(cmd),input=json.dumps(doc) if doc else None,text=True,capture_output=True,check=True,timeout=timeout).stdout
    def admin(sql):return run('-n',db.NS,'exec','deployment/database','--','psql','-X','-U','traderx','-d','traderx','-Atc',sql).strip()
    def sessions():return json.loads(admin("SELECT coalesce(json_agg(json_build_object('pid',pid,'started',backend_start)),'[]'::json) FROM pg_stat_activity WHERE usename='lab_position' AND application_name='PostgreSQL JDBC Driver';"))
    def keys(rows):return {(r['pid'],r['started']) for r in rows}
    with (root/'console-run.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        assert run('config','current-context').strip()=='kind-traderx-security-lab'
        assert [n['metadata']['name'] for n in json.loads(run('get','nodes','-o','json'))['items']]==['traderx-security-lab-control-plane']
        assert json.loads((root/'database-permissions/state.json').read_text())['complete']
        folder=root/'database-rotation';folder.mkdir(mode=0o700,exist_ok=True);ledger=folder/'private-state.json'
        if ledger.exists():
            state=json.loads(ledger.read_text())
            if state['phase']=='complete':
                (folder/'rotation-result.json').write_text(json.dumps(public_result(state),indent=2)+'\n')
                print('Rotation already complete; SQL experiment verifies the retained proof.');return
            if not a.resume:raise ValueError('Inspect private phase record and use --resume')
        else:
            current=json.loads(run('-n',db.NS,'get','secret',db.secret_name(NAME),'-o','json'))
            old=base64.b64decode(current['data']['password']).decode();assert base64.b64decode(current['data']['username']).decode()==ROLE
            assert sql_login(k,ROLE,old,'SELECT current_user;').stdout.strip()==ROLE
            pods=json.loads(run('-n',db.NS,'get','pods','-l','app='+NAME,'-o','json'))['items'];assert len(pods)==1
            before=sessions();assert before
            state={'phase':'prepared','started_at':datetime.now(timezone.utc).isoformat(),'old_password':old,'new_password':secrets.token_hex(24),'old_pod_uid':pods[0]['metadata']['uid'],'old_secret_version':current['metadata']['resourceVersion'],'sessions_before':before}
        def save():
            tmp=ledger.with_suffix('.tmp');tmp.write_text(json.dumps(state,indent=2)+'\n');tmp.replace(ledger)
        assert re.fullmatch('[0-9a-f]{48}',state['new_password']), 'Invalid recorded credential format'
        save()
        if state['phase']=='prepared':
            reply=subprocess.run(k+['-n',db.NS,'exec','-i','deployment/database','--','psql','-X','-v','ON_ERROR_STOP=1','-U','traderx','-d','traderx'],input="ALTER ROLE lab_position PASSWORD '"+state['new_password']+"';",text=True,capture_output=True,timeout=45)
            if reply.returncode:raise RuntimeError('Credential change failed; no credential SQL printed')
            assert rejected(sql_login(k,ROLE,state['old_password'],'SELECT current_user;'))
            accepted=sql_login(k,ROLE,state['new_password'],'SELECT current_user;');assert accepted.returncode==0 and accepted.stdout.strip()==ROLE
            remaining=keys(sessions()) & keys(state['sessions_before'])
            state.update(phase='password-changed',old_fresh_login_rejected=True,new_login_passed=True,old_jdbc_sessions_survived_change=len(remaining));save()
            print('Retired password rejected on new connection; '+str(len(remaining))+' established JDBC sessions remain.',flush=True)
        if state['phase']=='password-changed':
            secret={'apiVersion':'v1','kind':'Secret','metadata':{'name':db.secret_name(NAME),'namespace':db.NS},'type':'Opaque','stringData':{'username':ROLE,'password':state['new_password']}}
            run('apply','--server-side','--field-manager=traderx-security-lab','-f','-',doc=secret)
            state['phase']='secret-updated';save()
        if state['phase']=='secret-updated':
            # Deterministic annotation makes interrupted restart requests idempotent.
            run('-n',db.NS,'patch','deployment',NAME,'--type=merge','-p',json.dumps({'spec':{'template':{'metadata':{'annotations':{'security-lab.traderx/credential-rotation':state['started_at']}}}}}))
            state['phase']='restarting';save()
        if state['phase']=='restarting':
            run('-n',db.NS,'rollout','status','deployment/'+NAME,'--timeout=420s',timeout=450)
            pods=json.loads(run('-n',db.NS,'get','pods','-l','app='+NAME,'-o','json'))['items'];assert len(pods)==1 and pods[0]['metadata']['uid']!=state['old_pod_uid']
            deadline=time.monotonic()+60
            while True:
                after=sessions()
                if after and not (keys(after)&keys(state['sessions_before'])):break
                if time.monotonic()>deadline:raise TimeoutError('Original JDBC sessions not fully drained')
                time.sleep(1)
            assert rejected(sql_login(k,ROLE,state['old_password'],'SELECT current_user;'))
            current=json.loads(run('-n',db.NS,'get','secret',db.secret_name(NAME),'-o','json'))
            assert base64.b64decode(current['data']['password']).decode()==state['new_password']
            state.update(phase='verifying',new_pod_uid=pods[0]['metadata']['uid'],sessions_after=after,new_secret_version=current['metadata']['resourceVersion'],old_jdbc_sessions_drained=True);save()
            print('Replacement Pod ready; all original JDBC sessions drained.',flush=True)
        if state['phase']=='verifying':
            repo=Path(__file__).resolve().parents[2]
            with (folder/'sql-check.log').open('w') as output:subprocess.run([os.sys.executable,str(repo/'scripts/security-lab/verify_database_permissions.py'),'--runtime-dir',str(root),'--output-dir',str(folder)],stdout=output,stderr=subprocess.STDOUT,check=True,timeout=180)
            env=os.environ.copy();env['TRADERX_SECURITY_RUNTIME']=str(root)
            with (folder/'trading-smoke.log').open('w') as output:subprocess.run(['bash',str(repo/'scripts/security-lab/test-reference.sh')],env=env,stdout=output,stderr=subprocess.STDOUT,check=True,timeout=600)
            state.update(phase='complete',completed_at=datetime.now(timezone.utc).isoformat(),trading_smoke_sha256=hashlib.sha256((folder/'trading-smoke.log').read_bytes()).hexdigest());save()
        public=public_result(state)
        (folder/'rotation-result.json').write_text(json.dumps(public,indent=2)+'\n')
        print('PASS: runtime credential rotated, retired login rejected, old pool drained and full trading passed.',flush=True)

if __name__=='__main__':main()
