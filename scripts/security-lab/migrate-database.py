#!/usr/bin/env python3
"""Quiesce the isolated lab, preserve its database, migrate to PVC and prove restart recovery."""
import argparse
from datetime import datetime,timezone
import fcntl
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time
import workloads
import database_workload as db


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-dir',type=Path,default=Path('/private/tmp/traderx-security-runtime'))
    parser.add_argument('--resume',action='store_true')
    args=parser.parse_args();os.umask(0o077);root=args.runtime_dir.resolve()
    k=['kubectl','--kubeconfig',str(root/'kubeconfig')]
    def run(*cmd,doc=None,timeout=90):
        return subprocess.run(k+list(cmd),input=json.dumps(doc) if doc is not None else None,text=True,capture_output=True,check=True,timeout=timeout).stdout
    def sql(query):return run('-n',db.NS,'exec','deployment/database','--','psql','-U','traderx','-d','traderx','-At','-v','ON_ERROR_STOP=1','-c',query).strip()
    def fingerprint():
        tables=sql("SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename").splitlines()
        result={}
        for table in tables:
            identifier='"'+table.replace('"','""')+'"'
            values=sql('SELECT count(*), md5(COALESCE(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text)::text,\'[]\')) FROM public.'+identifier+' t').split('|')
            result[table]={'rows':int(values[0]),'content_md5':values[1]}
        if set(result)!={'accounts','accountusers','orderbook','positions','trades'}:raise ValueError('Unexpected table set; review before migration')
        return result
    with (root/'console-run.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        if run('config','current-context').strip()!='kind-traderx-security-lab':raise ValueError('Wrong context')
        nodes=json.loads(run('get','nodes','-o','json'))['items']
        if [n['metadata']['name'] for n in nodes]!=['traderx-security-lab-control-plane']:raise ValueError('Wrong node')
        folder=root/'database-migration';folder.mkdir(mode=0o700,exist_ok=True)
        state_path=folder/'state.json';backup=folder/'database.dump'
        def save():
            temp=state_path.with_suffix('.tmp');temp.write_text(json.dumps(state,indent=2)+'\n');temp.replace(state_path)
        if state_path.exists():
            state=json.loads(state_path.read_text())
            if state['phase']=='complete': print('Migration already complete; use the database verifier.');return
            if not args.resume:raise ValueError('Migration record exists; inspect it and use --resume. Backup will not be overwritten.')
        else:
            if args.resume:raise ValueError('No migration record to resume')
            if json.loads(run('-n',db.NS,'get','pvc','-o','json'))['items']:raise ValueError('Existing PVCs require review before first migration')
            deployments=json.loads(run('-n',db.NS,'get','deployments','-o','json'))['items']
            replicas={d['metadata']['name']:d['spec'].get('replicas',1) for d in deployments if d['metadata']['name'] in workloads.NAMES}
            if set(replicas)!=set(workloads.NAMES):raise ValueError('Missing business deployments')
            state={'phase':'quiescing','started_at':datetime.now(timezone.utc).isoformat(),'replicas':replicas};save()
        try:
            if state['phase'] not in ['verified','resuming']:
                for name in workloads.NAMES:run('-n',db.NS,'scale','deployment/'+name,'--replicas=0')
                deadline=time.monotonic()+180
                while True:
                    pods=json.loads(run('-n',db.NS,'get','pods','-o','json'))['items']
                    if not any(p['metadata'].get('labels',{}).get('app') in workloads.NAMES for p in pods):break
                    if time.monotonic()>deadline:raise TimeoutError('Business Pods did not stop')
                    time.sleep(1)
                print('Writers stopped.',flush=True)
                if 'backup_sha256' not in state:
                    if backup.exists():raise ValueError('Unrecorded backup exists; inspect before resuming, never overwrite it')
                    before=fingerprint()
                    temporary=folder/'database.dump.partial'
                    with temporary.open('wb') as output:
                        subprocess.run(k+['-n',db.NS,'exec','deployment/database','--','pg_dump','-U','traderx','-d','traderx','-Fc'],stdout=output,stderr=subprocess.PIPE,check=True,timeout=180)
                    if fingerprint()!=before:raise ValueError('Dataset changed during backup')
                    temporary.replace(backup)
                    state.update(before=before,backup_sha256=hashlib.sha256(backup.read_bytes()).hexdigest(),phase='backed-up');save()
                if hashlib.sha256(backup.read_bytes()).hexdigest()!=state['backup_sha256']:raise ValueError('Backup hash mismatch; refusing restore')
                print('Backup and table fingerprints verified.',flush=True)
                rendered=db.render(json.loads((root/'reference.json').read_text()))
                (folder/'manifest.json').write_text(json.dumps(rendered,indent=2)+'\n')
                for resource in rendered['items']:run('apply','-f','-',doc=resource)
                run('-n',db.NS,'rollout','status','deployment/database','--timeout=300s',timeout=330)
                state['phase']='restoring';save()
                with backup.open('rb') as source:
                    subprocess.run(k+['-n',db.NS,'exec','-i','deployment/database','--','pg_restore','-U','traderx','-d','traderx','--clean','--if-exists','--exit-on-error','--single-transaction','--no-owner'],stdin=source,stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=True,timeout=180)
                if fingerprint()!=state['before']:raise ValueError('Restored fingerprints differ; writers remain stopped')
                print('Restore verified. Testing a database Pod restart.',flush=True)
                pods=json.loads(run('-n',db.NS,'get','pods','-l','app=database','-o','json'))['items'];state['pod_before_restart']=pods[0]['metadata']['uid'];save()
                run('-n',db.NS,'rollout','restart','deployment/database')
                run('-n',db.NS,'rollout','status','deployment/database','--timeout=300s',timeout=330)
                pods=json.loads(run('-n',db.NS,'get','pods','-l','app=database','-o','json'))['items'];state['pod_after_restart']=pods[0]['metadata']['uid']
                if state['pod_before_restart']==state['pod_after_restart'] or fingerprint()!=state['before']:raise ValueError('Restart persistence check failed; writers remain stopped')
                state['phase']='verified';state['persistence_verified']=True;save()
                print('Every table survived Pod replacement unchanged.',flush=True)
            state['phase']='resuming';save()
            for name,count in state['replicas'].items():
                run('-n',db.NS,'scale','deployment/'+name,'--replicas='+str(count))
                if count:run('-n',db.NS,'rollout','status','deployment/'+name,'--timeout=420s',timeout=450)
                print('Restored business replicas: '+name,flush=True)
            state.update(phase='complete',completed_at=datetime.now(timezone.utc).isoformat());save()
            print('Database migration complete. Run workload and trading acceptance checks.',flush=True)
        except Exception:
            print('Migration stopped in phase '+state['phase']+'. Backup and phase record retained; use --resume after correcting the cause.',flush=True)
            raise

if __name__=='__main__':main()
