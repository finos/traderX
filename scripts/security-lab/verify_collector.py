#!/usr/bin/env python3
"""Verify collector exception, namespace-wide admission denials and fresh log delivery."""
import argparse
import copy
from datetime import datetime,timezone
import hashlib
import json
from pathlib import Path
import subprocess
import uuid
import collector_boundary as cb
from log_probe import probe


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--runtime-dir',type=Path,default=Path('/private/tmp/traderx-security-runtime'));parser.add_argument('--output-dir',type=Path,required=True)
    args=parser.parse_args();root=args.runtime_dir.resolve();k=['kubectl','--kubeconfig',str(root/'kubeconfig')]
    def run(*cmd,doc=None,check=True):return subprocess.run(k+list(cmd),input=json.dumps(doc) if doc else None,text=True,capture_output=True,check=check,timeout=45)
    assert run('config','current-context').stdout.strip()=='kind-traderx-security-lab'
    assert [n['metadata']['name'] for n in json.loads(run('get','nodes','-o','json').stdout)['items']]==['traderx-security-lab-control-plane']
    ns=json.loads(run('get','namespace',cb.APP,'-o','json').stdout)
    mode=ns['metadata']['labels']['pod-security.kubernetes.io/enforce']
    assert mode in ['baseline','restricted']
    assert ns['metadata']['labels']['pod-security.kubernetes.io/enforce-version']=='v1.35'
    assert not json.loads(run('-n',cb.APP,'get','daemonset','promtail','--ignore-not-found','-o','json').stdout or '{}')
    assert not json.loads(run('-n',cb.APP,'get','pods','-l','app=promtail','-o','json').stdout)['items']
    assert not run('get','clusterrolebinding','promtail-traderx','--ignore-not-found','-o','name').stdout.strip()
    expected=cb.render(json.loads((root/'reference.json').read_text()))
    ds=json.loads(run('-n',cb.INFRA,'get','daemonset','promtail','-o','json').stdout)
    assert ds['status']['numberReady']==ds['status']['desiredNumberScheduled']==1
    assert ds['status']['observedGeneration']==ds['metadata']['generation']
    desired=next(x for x in expected['items'] if x['kind']=='DaemonSet')
    for d in expected['items']:
        if d['kind']=='ValidatingAdmissionPolicy':
            live=json.loads(run('get','validatingadmissionpolicy',d['metadata']['name'],'-o','json').stdout)
            for field in ['failurePolicy','matchConditions','validations']:assert live['spec'][field]==d['spec'][field]
            assert not live.get('status',{}).get('typeChecking',{}).get('expressionWarnings')
        elif d['kind'] in ['ValidatingAdmissionPolicyBinding','ClusterRoleBinding','ClusterRole']:
            live=json.loads(run('get',d['kind'],d['metadata']['name'],'-o','json').stdout)
            for field in ['spec','subjects','roleRef','rules']:
                if field in d:assert live[field]==d[field],(d['kind'],field)
    cm=json.loads(run('-n',cb.INFRA,'get','configmap','observability-promtail-config','-o','json').stdout)
    assert cm['data']==next(x for x in expected['items'] if x['kind']=='ConfigMap')['data']
    pods=json.loads(run('-n',cb.INFRA,'get','pods','-o','json').stdout)['items'];assert len(pods)==1
    live=pods[0];spec=live['spec'];wanted=desired['spec']['template']['spec']
    for field in ['serviceAccountName','automountServiceAccountToken','securityContext','volumes']:assert spec[field]==wanted[field],field
    for field in ['image','command','args','securityContext','resources','volumeMounts']:assert spec['containers'][0][field]==wanted['containers'][0][field],field
    node=['docker','exec','traderx-security-lab-control-plane']
    containers=json.loads(subprocess.check_output(node+['crictl','ps','-o','json']))['containers']
    matches=[c for c in containers if c['metadata']['name']=='promtail' and c['labels'].get('io.kubernetes.pod.namespace')==cb.INFRA];assert len(matches)==1
    info=json.loads(subprocess.check_output(node+['crictl','inspect',matches[0]['id']]))['info'];pid=int(info['pid']);assert pid>0
    runtime=info['runtimeSpec'];assert runtime['process']['user']['uid']==0 and runtime['process']['noNewPrivileges'] and runtime['root']['readonly']
    assert not any(runtime['process'].get('capabilities',{}).values())
    status=dict(line.split(':',1) for line in subprocess.check_output(node+['cat',f'/proc/{pid}/status'],text=True).splitlines() if ':' in line)
    assert status['NoNewPrivs'].strip()=='1' and status['Seccomp'].strip()=='2' and int(status['CapEff'].strip(),16)==0
    host_mount=next(m for m in runtime['mounts'] if m['destination']=='/var/log/pods');assert 'ro' in host_mount['options']
    identity='system:serviceaccount:'+cb.INFRA+':'+cb.SA
    perms=[]
    for verb,resource,allowed in [('list','pods',True),('list','nodes',True),('list','namespaces',True),('get','secrets',False),('create','deployments',False),('create','pods',False),('update','namespaces',False),('update','configmaps',False)]:
        answer=run('auth','can-i',verb,resource,'--as='+identity,'--as-group=system:serviceaccounts','--as-group=system:serviceaccounts:'+cb.INFRA,'--as-group=system:authenticated','-n',cb.APP,check=False)
        assert answer.stdout.strip()==('yes' if allowed else 'no'),answer.stderr
        perms.append({'operation':verb+' '+resource,'allowed':allowed})
    safe={'apiVersion':'v1','kind':'Pod','metadata':{'name':'collector-check-'+uuid.uuid4().hex[:8],'namespace':cb.INFRA},'spec':wanted}
    run('create','--dry-run=server','-f','-',doc=safe)
    infra_checks=[]
    for case in ['host-root','writable-host','privileged','capability','writable-root','default-identity','unapproved-image','shell-command','extra-container','long-token','host-network','secret-volume']:
        d=copy.deepcopy(safe);p=d['spec'];c=p['containers'][0]
        if case=='host-root':p['volumes'][1]['hostPath']['path']='/'
        elif case=='writable-host':c['volumeMounts'][1]['readOnly']=False
        elif case=='root':p['securityContext'].update(runAsUser=0,runAsNonRoot=False)
        elif case=='escalation':c['securityContext']['allowPrivilegeEscalation']=True
        elif case=='missing-seccomp':p['securityContext'].pop('seccompProfile')
        elif case=='missing-drop':c['securityContext'].pop('capabilities')
        elif case=='privileged':c['securityContext'].update(privileged=True,allowPrivilegeEscalation=True)
        elif case=='capability':c['securityContext']['capabilities']['add']=['SYS_ADMIN']
        elif case=='writable-root':c['securityContext']['readOnlyRootFilesystem']=False
        elif case=='default-identity':p['serviceAccountName']='default'
        elif case=='unapproved-image':c['image']='busybox:latest'
        elif case=='shell-command':c['command']=['sh']
        elif case=='extra-container':p['containers'].append({'name':'extra','image':c['image']})
        elif case=='long-token':p['volumes'][3]['projected']['sources'][0]['serviceAccountToken']['expirationSeconds']=86400
        elif case=='host-network':p['hostNetwork']=True
        elif case=='secret-volume':p['volumes'].append({'name':'extra-secret','secret':{'secretName':'unrelated'}})
        reply=run('create','--dry-run=server','-f','-',doc=d,check=False)
        assert reply.returncode!=0 and cb.POLICY+'-pods' in reply.stderr and 'CB:' in reply.stderr,(case,reply.stderr)
        infra_checks.append({'case':case,'denied_by':cb.POLICY+'-pods'})
    debug=copy.deepcopy(live);debug['spec']['ephemeralContainers']=[{'name':'unapproved-debug','image':spec['containers'][0]['image'],'command':['true']}]
    reply=run('replace','--raw',f'/api/v1/namespaces/{cb.INFRA}/pods/{live["metadata"]["name"]}/ephemeralcontainers?dryRun=All','-f','-',doc=debug,check=False)
    assert reply.returncode!=0 and cb.POLICY+'-pods' in reply.stderr
    infra_checks.append({'case':'debug-container','denied_by':cb.POLICY+'-pods'})
    pin=json.loads((Path(__file__).resolve().parents[2]/'specs/012-platform-convergence-c3/security-lab/evidence/2026-11-22-platform-image.lock.json').read_text())
    good={'apiVersion':'v1','kind':'Pod','metadata':{'name':'unrelated-'+uuid.uuid4().hex[:8],'namespace':cb.APP,'labels':{'app':'unrelated'}},'spec':{'serviceAccountName':'default','automountServiceAccountToken':False,'securityContext':{'runAsNonRoot':True,'runAsUser':10001,'seccompProfile':{'type':'RuntimeDefault'}},'containers':[{'name':'probe','image':pin['image'],'securityContext':{'allowPrivilegeEscalation':False,'readOnlyRootFilesystem':True,'capabilities':{'drop':['ALL']}}}]}}
    run('create','--dry-run=server','-f','-',doc=good)
    app_checks=[]
    cases=['privileged','host-network','host-pid','host-ipc','host-path','capability','unconfined','host-port']
    if mode=='restricted':cases += ['root','escalation','missing-seccomp','missing-drop']
    for case in cases:
        d=copy.deepcopy(good);p=d['spec'];c=p['containers'][0]
        if case=='root':p['securityContext'].update(runAsUser=0,runAsNonRoot=False)
        elif case=='escalation':c['securityContext']['allowPrivilegeEscalation']=True
        elif case=='missing-seccomp':p['securityContext'].pop('seccompProfile')
        elif case=='missing-drop':c['securityContext'].pop('capabilities')
        elif case=='privileged':c['securityContext'].update(privileged=True,allowPrivilegeEscalation=True)
        elif case=='host-network':p['hostNetwork']=True
        elif case=='host-pid':p['hostPID']=True
        elif case=='host-ipc':p['hostIPC']=True
        elif case=='host-path':p['volumes']=[{'name':'host','hostPath':{'path':'/tmp'}}]
        elif case=='capability':c['securityContext']['capabilities']['add']=['SYS_ADMIN']
        elif case=='unconfined':p['securityContext']['seccompProfile']['type']='Unconfined'
        elif case=='host-port':c['ports']=[{'containerPort':8080,'hostPort':8080}]
        reply=run('create','--dry-run=server','-f','-',doc=d,check=False)
        assert reply.returncode!=0 and 'violates PodSecurity' in reply.stderr and mode+':v1.35' in reply.stderr,(case,reply.stderr)
        app_checks.append({'case':case,'denied_by':'Pod Security Admission '+mode+':v1.35'})
    limitation=copy.deepcopy(good);limitation['spec']['securityContext'].update(runAsUser=0,runAsNonRoot=False);limitation['spec']['containers'][0]['securityContext']['readOnlyRootFilesystem']=False
    counterexample=run('create','--dry-run=server','-f','-',doc=limitation,check=False)
    if mode=='baseline':assert counterexample.returncode==0
    else:assert counterexample.returncode!=0 and 'restricted:v1.35' in counterexample.stderr
    delivery=probe(k)
    result={'scenario':'collector-boundary','status':'passed','recorded_at':datetime.now(timezone.utc).isoformat(),'application_admission':app_checks,'collector_admission':infra_checks,'permissions':perms,'fresh_log_delivery':delivery,
      'collector':{'namespace':cb.INFRA,'pod_uid':live['metadata']['uid'],'image':spec['containers'][0]['image'],'uid':0,'capabilities':'none','no_new_privileges':True,'seccomp_mode':2,'root_readonly':True,'host_logs_readonly':True,'explicit_api_token_lifetime_seconds':3600},
      'application_policy':mode+':v1.35','baseline_allows_root_writable_pod_dry_run':mode=='baseline','limitations':['Restricted does not require read-only roots, resource bounds or token suppression for unrelated workloads; named workload policies add these controls.' if mode=='restricted' else 'Application namespace is Baseline, not Restricted.','Collector can read all mounted node pod-log files; namespace filter is collection scope.','Fresh checkpoint replay can duplicate old logs.'],
      'source_hashes':{name:hashlib.sha256((Path(__file__).parent/name).read_bytes()).hexdigest() for name in ['collector_boundary.py','isolate-collector.py','verify_collector.py','log_probe.py']}}
    args.output_dir.mkdir(parents=True,exist_ok=True);(args.output_dir/'collector-result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(f'PASS: {len(app_checks)} namespace {mode} denials, 13 collector denials, read-only discovery permissions and fresh Loki log receipt.')

if __name__=='__main__':main()
