#!/usr/bin/env python3
"""Preserve local observability stores on PVCs, with explicit phase records."""
import argparse
from datetime import datetime,timezone
import fcntl
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time
import observability_workloads as obs
from observability_migration import archive_manifest,semantic_before,semantic_after


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--runtime-dir',type=Path,default=Path('/private/tmp/traderx-security-runtime'));parser.add_argument('--resume',action='store_true')
    args=parser.parse_args();os.umask(0o077);root=args.runtime_dir.resolve();k=['kubectl','--kubeconfig',str(root/'kubeconfig')];node=['docker','exec','traderx-security-lab-control-plane']
    def run(*cmd,doc=None,timeout=90):return subprocess.run(k+list(cmd),input=json.dumps(doc) if doc else None,text=True,capture_output=True,check=True,timeout=timeout).stdout
    with (root/'console-run.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        assert run('config','current-context').strip()=='kind-traderx-security-lab'
        assert [n['metadata']['name'] for n in json.loads(run('get','nodes','-o','json'))['items']]==['traderx-security-lab-control-plane']
        folder=root/'observability-migration';folder.mkdir(mode=0o700,exist_ok=True);ledger=folder/'state.json'
        if ledger.exists():
            state=json.loads(ledger.read_text())
            if state.get('complete'):print('Migration already recorded complete; use workload verification.');return
            if not args.resume:raise ValueError('Inspect existing phase record and use --resume; backups are never overwritten')
        else:state={'started_at':datetime.now(timezone.utc).isoformat(),'stores':{}}
        def save():
            tmp=ledger.with_suffix('.tmp');tmp.write_text(json.dumps(state,indent=2)+'\n');tmp.replace(ledger)
        save();ref=json.loads((root/'reference.json').read_text());rendered=obs.render(ref)
        helper_image=json.loads((Path(__file__).resolve().parents[2]/'specs/012-platform-convergence-c3/security-lab/evidence/2026-11-22-platform-image.lock.json').read_text())['image']
        # Admission changes do not restart existing workloads.
        for d in rendered['items']:
            if d['kind'] in ['ValidatingAdmissionPolicy','ValidatingAdmissionPolicyBinding']:run('apply','-f','-',doc=d)
        for name in obs.NAMES:
            entry=state['stores'].setdefault(name,{'phase':'initial'});save()
            if entry['phase']=='complete':continue
            helper='lab-restore-'+name;archive=folder/(name+'.tar')
            deployment=next(x for x in rendered['items'] if x['kind']=='Deployment' and x['metadata']['name']==name)
            if entry['phase']=='initial':
                if archive.exists():raise ValueError('Unrecorded archive requires review: '+name)
                if run('-n',obs.NS,'get','pvc','lab-'+name+'-data','--ignore-not-found','-o','name').strip():raise ValueError('Unowned PVC requires review: '+name)
                entry['semantic_before']=semantic_before(k,name);entry['phase']='preparing';save()
            if entry['phase'] in ['preparing','quiesced','restoring']:
                pvc=next(x for x in rendered['items'] if x['kind']=='PersistentVolumeClaim' and x['metadata']['name']=='lab-'+name+'-data')
                run('apply','-f','-',doc=pvc)
                pod={'apiVersion':'v1','kind':'Pod','metadata':{'name':helper,'namespace':obs.NS,'labels':{'app':'lab-restore'}},'spec':{'restartPolicy':'Never','automountServiceAccountToken':False,'securityContext':{'runAsNonRoot':True,'runAsUser':10001,'runAsGroup':10001,'fsGroup':10001,'seccompProfile':{'type':'RuntimeDefault'}},'containers':[{'name':'restore','image':helper_image,'command':['sh','-c','sleep 1800'],'securityContext':{'allowPrivilegeEscalation':False,'readOnlyRootFilesystem':True,'capabilities':{'drop':['ALL']}},'resources':{'requests':{'cpu':'10m','memory':'32Mi'},'limits':{'cpu':'1','memory':'128Mi'}},'volumeMounts':[{'name':'store','mountPath':'/restore'}]}],'volumes':[{'name':'store','persistentVolumeClaim':{'claimName':'lab-'+name+'-data'}}]}}
                run('apply','-f','-',doc=pod);run('-n',obs.NS,'wait','--for=condition=Ready','pod/'+helper,'--timeout=120s',timeout=140)
            if entry['phase']=='preparing':
                if archive.exists():raise ValueError('Unrecorded checkpoint requires review: '+name)
                containers=json.loads(subprocess.check_output(node+['crictl','ps','-o','json']))['containers'];matches=[c for c in containers if c['metadata']['name']==name and c['labels'].get('io.kubernetes.pod.namespace')==obs.NS];assert len(matches)==1
                container=matches[0];info=json.loads(subprocess.check_output(node+['crictl','inspect',container['id']]))['info'];pid=int(info['pid']);assert pid>0
                entry['old_pod_uid']=container['labels']['io.kubernetes.pod.uid'];save()
                paused=False
                try:
                    subprocess.run(node+['ctr','-n','k8s.io','tasks','pause',container['id']],check=True,timeout=15);paused=True
                    partial=archive.with_suffix('.partial')
                    with partial.open('wb') as output:
                        subprocess.run(node+['tar','--one-file-system','-C',f'/proc/{pid}/root','-cf','-']+[p.lstrip('/') for p in obs.PATHS[name]],stdout=output,stderr=subprocess.PIPE,check=True,timeout=20)
                    partial.replace(archive)
                    entry.update(phase='captured',archive_sha256=hashlib.sha256(archive.read_bytes()).hexdigest());save()
                    run('-n',obs.NS,'scale','deployment/'+name,'--replicas=0',timeout=20)
                    entry['phase']='quiesced';save()
                finally:
                    if paused:
                        # The task may already have terminated after the scale request.
                        subprocess.run(node+['ctr','-n','k8s.io','tasks','resume',container['id']],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=15)
                print(name+': private checkpoint captured; old server stopping.',flush=True)
            if entry['phase']=='captured':raise ValueError('Captured but not quiesced: inspect original service before reusing an older checkpoint')
            if entry['phase'] in ['quiesced','restoring']:
                run('-n',obs.NS,'wait','--for=delete','pod','-l','app='+name,'--timeout=120s',timeout=140)
                assert hashlib.sha256(archive.read_bytes()).hexdigest()==entry['archive_sha256']
                expected=archive_manifest(archive,obs.PATHS[name]);entry['phase']='restoring';save()
                with archive.open('rb') as source:
                    reply=subprocess.run(k+['-n',obs.NS,'exec','-i',helper,'--','tar','--no-same-owner','-xpf','-','-C','/restore'],stdin=source,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=120)
                    if reply.returncode:raise RuntimeError(reply.stderr.decode(errors='replace')[-4000:])
                sums=run('-n',obs.NS,'exec',helper,'--','find','/restore','-type','f','-exec','sha256sum','{}','+',timeout=120)
                actual={line[66:].removeprefix('/restore/'):line[:64] for line in sums.splitlines()}
                if actual!=expected:raise ValueError('Restored file content mismatch: '+name)
                entry.update(phase='verified',file_count=len(expected),file_manifest_sha256=hashlib.sha256(json.dumps(expected,sort_keys=True).encode()).hexdigest());save()
                print(name+': every restored file matches the archive.',flush=True)
            if entry['phase']=='verified':
                run('-n',obs.NS,'delete','pod',helper,'--ignore-not-found','--grace-period=1','--wait=true','--timeout=30s')
                sa=next(x for x in rendered['items'] if x['kind']=='ServiceAccount' and x['metadata']['name']=='lab-'+name);run('apply','-f','-',doc=sa)
                entry['phase']='starting';save()
                run('apply','-f','-',doc=deployment)
            if entry['phase']=='starting':
                # Safe to reapply: once started, never restore an older backup over this PVC.
                run('apply','-f','-',doc=deployment)
                run('-n',obs.NS,'rollout','status','deployment/'+name,'--timeout=300s',timeout=330)
                entry['semantic_after']=semantic_after(k,name,entry['semantic_before'])
                pod=json.loads(run('-n',obs.NS,'get','pods','-l','app='+name,'-o','json'))['items'][0]
                entry.update(phase='complete',new_pod_uid=pod['metadata']['uid'],completed_at=datetime.now(timezone.utc).isoformat());save()
                print(name+': restricted service ready; retained historical data verified.',flush=True)
        state.update(complete=True,completed_at=datetime.now(timezone.utc).isoformat());save()
        print('All four stores migrated. Verify workload/admission and trading before claiming completion.',flush=True)

if __name__=='__main__':main()
