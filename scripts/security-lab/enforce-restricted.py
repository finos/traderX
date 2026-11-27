#!/usr/bin/env python3
"""Enable namespace Restricted only after all nineteen reviewed workloads conform."""
import argparse
import fcntl
import json
from pathlib import Path
import subprocess
import workloads
import support_workloads
import database_workload
import observability_workloads


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-dir',type=Path,default=Path('/private/tmp/traderx-security-runtime'))
    args=parser.parse_args();root=args.runtime_dir.resolve()
    k=['kubectl','--kubeconfig',str(root/'kubeconfig')]
    def run(*cmd):return subprocess.check_output(k+list(cmd),text=True,timeout=45)
    with (root/'console-run.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        assert run('config','current-context').strip()=='kind-traderx-security-lab'
        assert [n['metadata']['name'] for n in json.loads(run('get','nodes','-o','json'))['items']]==['traderx-security-lab-control-plane']
        assert json.loads((root/'observability-migration/state.json').read_text())['complete']
        assert not json.loads(run('-n',workloads.NS,'get','daemonsets','-o','json'))['items']
        reference=json.loads((root/'reference.json').read_text())
        live={d['metadata']['name']:d for d in json.loads(run('-n',workloads.NS,'get','deployments','-o','json'))['items']}
        names=[]
        for group in [workloads,support_workloads,database_workload,observability_workloads]:
            for expected in group.render(reference)['items']:
                if expected['kind']!='Deployment':continue
                name=expected['metadata']['name'];names.append(name);d=live[name]
                assert d['status'].get('availableReplicas')==1 and d['status']['observedGeneration']==d['metadata']['generation'],name
                desired=expected['spec']['template']['spec'];actual=d['spec']['template']['spec']
                for field in ['securityContext','serviceAccountName','automountServiceAccountToken','volumes']:assert actual[field]==desired[field],(name,field)
                assert len(actual['containers'])==1
                for field in ['securityContext','resources','volumeMounts','image']:assert actual['containers'][0][field]==desired['containers'][0][field],(name,field)
        assert len(names)==19 and set(names)==set(live)
        # API dry-run evaluates existing Pods when the namespace label changes.
        cmd=k+['label','namespace',workloads.NS,'pod-security.kubernetes.io/enforce=restricted','pod-security.kubernetes.io/enforce-version=v1.35','--overwrite']
        check=subprocess.run(cmd+['--dry-run=server'],text=True,capture_output=True,check=True,timeout=45)
        if 'Warning:' in check.stderr:raise RuntimeError(check.stderr)
        subprocess.run(cmd,check=True,timeout=45)
        print('Restricted v1.35 enabled after all nineteen workload templates passed prerequisite checks.')

if __name__=='__main__':main()
