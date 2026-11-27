#!/usr/bin/env python3
"""Apply or roll back a reviewed workload group in the isolated lab."""
import argparse
import fcntl
import json
from pathlib import Path
import subprocess
import workloads
import support_workloads
import database_permissions


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-dir',type=Path,default=Path('/private/tmp/traderx-security-runtime'))
    parser.add_argument('--profile',choices=['business','support'],default='business')
    parser.add_argument('--rollback',action='store_true')
    args=parser.parse_args(); root=args.runtime_dir.resolve()
    profile=support_workloads if args.profile=='support' else workloads
    with (root/'console-run.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        k=['kubectl','--kubeconfig',str(root/'kubeconfig')]
        def run(*cmd,doc=None):
            return subprocess.run(k+list(cmd),input=json.dumps(doc) if doc else None,text=True,check=True,stdout=subprocess.PIPE).stdout
        if run('config','current-context').strip()!='kind-traderx-security-lab': raise ValueError('Wrong context')
        nodes=json.loads(run('get','nodes','-o','json'))['items']
        if [x['metadata']['name'] for x in nodes]!=['traderx-security-lab-control-plane']: raise ValueError('Wrong node')
        from candidate_images import overlay
        candidate_path=root/'candidate-rollout/state.json'
        reference=overlay(json.loads((root/'reference.json').read_text()),json.loads(candidate_path.read_text()) if candidate_path.exists() else None)
        if args.rollback:
            policies=[profile.POLICY]
            if args.profile=='support': policies += [profile.POLICY+'-pods',workloads.POLICY+'-pods']
            elif args.profile=='business': policies += [workloads.POLICY+'-pods']
            for policy in policies:
                print(run('delete','validatingadmissionpolicybinding',policy,'--ignore-not-found'))
                print(run('delete','validatingadmissionpolicy',policy,'--ignore-not-found'))
            docs=[d for d in reference['items'] if d['kind']=='Deployment' and d['metadata']['name'] in profile.NAMES]
            if args.profile=='support': docs += [d for d in reference['items'] if d['kind']=='Service' and d['metadata']['name']=='api-explorer']
        else:
            rendered=profile.render(reference)
            sql_state=root/'database-permissions/state.json'
            if args.profile=='business' and sql_state.exists() and json.loads(sql_state.read_text()).get('complete'):
                rendered=database_permissions.transform(rendered)
            (root/('support-workloads.json' if args.profile=='support' else 'workloads.json')).write_text(json.dumps(rendered,indent=2)+'\n')
            docs=rendered['items']
        for d in docs:
            print(run('apply','-f','-',doc=d),flush=True)
            if d['kind']=='Deployment':
                print(run('-n',workloads.NS,'rollout','status','deployment/'+d['metadata']['name'],'--timeout=420s'),flush=True)

if __name__=='__main__': main()
