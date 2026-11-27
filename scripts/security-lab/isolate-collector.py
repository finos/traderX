#!/usr/bin/env python3
"""Cut over the log collector, verify delivery, then enforce application Baseline admission."""
import argparse
from datetime import datetime,timezone
import fcntl
import hashlib
import json
import os
from pathlib import Path
import subprocess
import collector_boundary as cb
from log_probe import probe


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--runtime-dir',type=Path,default=Path('/private/tmp/traderx-security-runtime'))
    args=parser.parse_args();root=args.runtime_dir.resolve();os.umask(0o077)
    k=['kubectl','--kubeconfig',str(root/'kubeconfig')]
    def run(*cmd,doc=None,check=True,timeout=90):return subprocess.run(k+list(cmd),input=json.dumps(doc) if doc else None,text=True,capture_output=True,check=check,timeout=timeout)
    with (root/'console-run.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        assert run('config','current-context').stdout.strip()=='kind-traderx-security-lab'
        assert [n['metadata']['name'] for n in json.loads(run('get','nodes','-o','json').stdout)['items']]==['traderx-security-lab-control-plane']
        folder=root/'collector-cutover';folder.mkdir(mode=0o700,exist_ok=True)
        reference=json.loads((root/'reference.json').read_text());rendered=cb.render(reference)
        original=next(d for d in reference['items'] if d['kind']=='DaemonSet' and d['metadata']['name']=='promtail')
        prior=run('-n',cb.APP,'get','daemonset','promtail','-o','json',check=False)
        if prior.returncode and (folder/'result.json').exists() and json.loads((folder/'result.json').read_text()).get('phase')=='complete':
            print('Cutover already recorded complete; use the collector verifier for current status.');return
        if prior.returncode:
            raise ValueError('Original collector absent; use the verifier for an already completed cutover, or inspect the retained cutover record before recovery')
        before=probe(k);print('Existing log delivery verified.',flush=True)
        node=['docker','exec','traderx-security-lab-control-plane']
        cs=json.loads(subprocess.check_output(node+['crictl','ps','-o','json']))['containers']
        matches=[c for c in cs if c['metadata']['name']=='promtail' and c['labels'].get('io.kubernetes.pod.namespace')==cb.APP]
        assert len(matches)==1
        info=json.loads(subprocess.check_output(node+['crictl','inspect',matches[0]['id']]))['info'];pid=int(info['pid']);assert pid>0
        checkpoint=folder/'original-checkpoints.tar'
        if checkpoint.exists():raise ValueError('Existing checkpoint archive: inspect earlier cutover record; do not overwrite')
        with checkpoint.open('wb') as target:
            subprocess.run(node+['tar','-C',f'/proc/{pid}/root/run/vector','-cf','-','.'],stdout=target,stderr=subprocess.PIPE,check=True,timeout=30)
        evidence={'started_at':datetime.now(timezone.utc).isoformat(),'before':before,'checkpoint_sha256':hashlib.sha256(checkpoint.read_bytes()).hexdigest(),'phase':'prepared'}
        def save(): (folder/'result.json').write_text(json.dumps(evidence,indent=2)+'\n')
        save();(folder/'manifest.json').write_text(json.dumps(rendered,indent=2)+'\n')
        for resource in rendered['items']:run('apply','-f','-',doc=resource)
        run('-n',cb.INFRA,'rollout','status','daemonset/promtail','--timeout=180s',timeout=200)
        print('Infrastructure collector running. Removing old collector.',flush=True)
        run('-n',cb.APP,'delete','daemonset','promtail','--wait=true','--timeout=60s')
        # Deletion of a controller alone does not prove all its Pods have terminated.
        run('-n',cb.APP,'wait','--for=delete','pod','-l','app=promtail','--timeout=90s',timeout=110)
        evidence['phase']='old-collector-removed';save()
        try:
            evidence['after']=probe(k)
        except Exception:
            run('apply','-f','-',doc=original)
            evidence['phase']='old-collector-restored-after-probe-failure';save()
            raise
        print('Fresh log reached Loki through the relocated collector.',flush=True)
        old_binding=json.loads(run('get','clusterrolebinding','promtail-traderx','-o','json').stdout)
        assert old_binding['subjects']==[{'kind':'ServiceAccount','name':'promtail','namespace':cb.APP}], 'Unexpected binding; review before removal'
        run('delete','clusterrolebinding','promtail-traderx')
        labels=[key+'='+value for key,value in cb.BASELINE.items()]
        run('label','namespace',cb.APP,*labels,'--overwrite')
        evidence.update(phase='complete',completed_at=datetime.now(timezone.utc).isoformat(),baseline=cb.BASELINE,duplicate_replay_possible=True);save()
        print('Cutover complete; application namespace enforces Baseline v1.35.',flush=True)

if __name__=='__main__':main()
