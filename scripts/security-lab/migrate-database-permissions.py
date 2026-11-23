#!/usr/bin/env python3
"""Private-checkpoint migration of four runtime SQL identities; no data restore."""
import argparse
from datetime import datetime,timezone
import fcntl
import hashlib
import json
import os
from pathlib import Path
import secrets
import subprocess
import database_permissions as db

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--runtime-dir',type=Path,default=Path('/private/tmp/traderx-security-runtime'));p.add_argument('--resume',action='store_true');a=p.parse_args();os.umask(0o077);root=a.runtime_dir.resolve();k=['kubectl','--kubeconfig',str(root/'kubeconfig')]
    def run(*cmd,doc=None,timeout=60):return subprocess.run(k+list(cmd),input=json.dumps(doc) if doc else None,text=True,capture_output=True,check=True,timeout=timeout).stdout
    with (root/'console-run.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        assert run('config','current-context').strip()=='kind-traderx-security-lab'
        assert [n['metadata']['name'] for n in json.loads(run('get','nodes','-o','json'))['items']]==['traderx-security-lab-control-plane']
        folder=root/'database-permissions';folder.mkdir(mode=0o700,exist_ok=True);ledger=folder/'state.json'
        if ledger.exists():
            state=json.loads(ledger.read_text())
            if state.get('complete'):print('SQL migration already complete.');return
            if not a.resume:raise ValueError('Inspect private phase record and use --resume')
        else:
            assert not (folder/'credentials.json').exists(),'Unrecorded credentials require review'
            existing=run('-n',db.NS,'exec','deployment/database','--','psql','-U','traderx','-d','traderx','-Atc',"SELECT rolname FROM pg_roles WHERE rolname IN ('lab_account','lab_position','lab_trade_processor','lab_order_matcher')")
            assert not existing.strip(),'Existing role names require ownership review'
            state={'phase':'initial','started_at':datetime.now(timezone.utc).isoformat(),'rolled_out':[]}
        def save():
            tmp=ledger.with_suffix('.tmp');tmp.write_text(json.dumps(state,indent=2)+'\n');tmp.replace(ledger)
        save();ref=json.loads((root/'reference.json').read_text())
        if state['phase']=='initial':
            for name in db.NAMES:(folder/(name+'-before.json')).write_text(run('-n',db.NS,'get','deployment',name,'-o','json'))
            before=run('-n',db.NS,'exec','deployment/database','--','psql','-U','traderx','-d','traderx','-Atc',"SELECT json_build_object('schemas',(SELECT json_agg(row_to_json(x)) FROM (SELECT nspname,nspacl FROM pg_namespace WHERE nspname='public') x),'database',(SELECT datacl FROM pg_database WHERE datname='traderx'),'tables',(SELECT json_agg(row_to_json(x)) FROM (SELECT relname,relacl FROM pg_class WHERE relnamespace='public'::regnamespace) x),'defaults',(SELECT json_agg(row_to_json(x)) FROM (SELECT * FROM pg_default_acl) x));")
            (folder/'grants-before.json').write_text(before)
            with (folder/'database.dump').open('wb') as f:subprocess.run(k+['-n',db.NS,'exec','deployment/database','--','pg_dump','-U','traderx','-d','traderx','-Fc'],stdout=f,stderr=subprocess.PIPE,check=True,timeout=120)
            credentials={name:{'username':grant['role'],'password':secrets.token_hex(24)} for name,grant in db.GRANTS.items()}
            (folder/'credentials.json').write_text(json.dumps(credentials));state.update(phase='prepared',backup_sha256=hashlib.sha256((folder/'database.dump').read_bytes()).hexdigest());save()
        credentials=json.loads((folder/'credentials.json').read_text())
        if state['phase']=='prepared':
            reply=subprocess.run(k+['-n',db.NS,'exec','-i','deployment/database','--','psql','-X','-v','ON_ERROR_STOP=1','-U','traderx','-d','traderx'],input=db.grant_sql(credentials),text=True,capture_output=True,timeout=60)
            if reply.returncode:raise RuntimeError('SQL grant transaction failed; no credential-bearing SQL is printed')
            state['phase']='roles-created';save();print('Four restricted SQL identities and explicit grants created.',flush=True)
        for d in db.deployments(ref):
            name=d['metadata']['name']
            if name in state['rolled_out']:continue
            secret={'apiVersion':'v1','kind':'Secret','metadata':{'name':db.secret_name(name),'namespace':db.NS},'type':'Opaque','stringData':credentials[name]}
            # Server-side apply avoids storing plaintext in a last-applied annotation.
            run('apply','--server-side','--field-manager=traderx-security-lab','-f','-',doc=secret)
            run('apply','-f','-',doc=d)
            run('-n',db.NS,'rollout','status','deployment/'+name,'--timeout=420s',timeout=450)
            state['rolled_out'].append(name);save();print(name+': ready with dedicated Secret-backed SQL identity.',flush=True)
        if not state.get('bootstrap_rotated'):
            bootstrap_file=folder/'bootstrap.json'
            if not bootstrap_file.exists():bootstrap_file.write_text(json.dumps({'username':'traderx','password':secrets.token_hex(24)}))
            bootstrap=json.loads(bootstrap_file.read_text())
            reply=subprocess.run(k+['-n',db.NS,'exec','-i','deployment/database','--','psql','-X','-v','ON_ERROR_STOP=1','-U','traderx','-d','traderx'],input="ALTER ROLE traderx PASSWORD '"+bootstrap['password']+"';",text=True,capture_output=True,timeout=60)
            if reply.returncode:raise RuntimeError('Bootstrap credential rotation failed')
            secret={'apiVersion':'v1','kind':'Secret','metadata':{'name':'lab-sql-bootstrap','namespace':db.NS},'type':'Opaque','stringData':bootstrap}
            run('apply','--server-side','--field-manager=traderx-security-lab','-f','-',doc=secret)
            run('apply','-f','-',doc=db.bootstrap_deployment(ref))
            run('-n',db.NS,'rollout','status','deployment/database','--timeout=300s',timeout=330)
            state['bootstrap_rotated']=True;save();print('Known demonstration administrator password retired; bootstrap Secret isolated to database Pod.',flush=True)
        for d in db.admission(ref):run('apply','-f','-',doc=d)
        state.update(complete=True,phase='complete',completed_at=datetime.now(timezone.utc).isoformat());save()
        print('SQL cutover complete. Live grant checks and trading acceptance still required.',flush=True)

if __name__=='__main__':main()
