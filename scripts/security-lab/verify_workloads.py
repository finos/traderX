#!/usr/bin/env python3
"""Verify a live workload group; unsafe variants use server dry-runs only."""
import argparse
import copy
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import uuid
import workloads
import support_workloads
import database_workload
import observability_workloads
import database_permissions


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-dir',type=Path,default=Path('/private/tmp/traderx-security-runtime'))
    parser.add_argument('--profile',choices=['business','support','database','observability'],default='business')
    parser.add_argument('--output-dir',type=Path,required=True)
    args=parser.parse_args(); root=args.runtime_dir.resolve()
    profile={'business':workloads,'support':support_workloads,'database':database_workload,'observability':observability_workloads}[args.profile]
    k=['kubectl','--kubeconfig',str(root/'kubeconfig')]
    def run(cmd,doc=None,check=True):
        return subprocess.run(cmd,input=json.dumps(doc) if doc else None,text=True,capture_output=True,check=check,timeout=45)
    def kub(*cmd,doc=None,check=True): return run(k+list(cmd),doc,check)
    if kub('config','current-context').stdout.strip()!='kind-traderx-security-lab': raise ValueError('Wrong context')
    nodes=json.loads(kub('get','nodes','-o','json').stdout)['items']
    if [n['metadata']['name'] for n in nodes]!=['traderx-security-lab-control-plane']: raise ValueError('Wrong nodes')
    policy=json.loads(kub('get','validatingadmissionpolicy',profile.POLICY,'-o','json').stdout)
    assert not policy.get('status',{}).get('typeChecking',{}).get('expressionWarnings'), 'Admission type warnings'
    binding=json.loads(kub('get','validatingadmissionpolicybinding',profile.POLICY,'-o','json').stdout)
    assert binding['spec']==profile.admission()[1]['spec'], 'Binding drift'
    wanted=profile.admission()[0]['spec']
    for field in ['failurePolicy','matchConditions','validations']:
        assert policy['spec'][field]==wanted[field], 'Admission policy drift: '+field
    actual_rules=copy.deepcopy(policy['spec']['matchConstraints']['resourceRules'])
    for rule in actual_rules: rule.pop('scope',None)
    assert actual_rules==wanted['matchConstraints']['resourceRules'], 'Admission rule drift'
    from candidate_images import overlay
    candidate_path=root/'candidate-rollout/state.json'
    reference=overlay(json.loads((root/'reference.json').read_text()),json.loads(candidate_path.read_text()) if candidate_path.exists() else None)
    expected=profile.render(reference)
    sql_state=root/'database-permissions/state.json'
    if args.profile=='business' and sql_state.exists() and json.loads(sql_state.read_text()).get('complete'):
        expected=database_permissions.transform(expected)
    if args.profile=='database' and sql_state.exists() and json.loads(sql_state.read_text()).get('complete'):
        expected['items']=[database_permissions.bootstrap_deployment(json.loads((root/'reference.json').read_text())) if d['kind']=='Deployment' else d for d in expected['items']]
    node=['docker','exec','traderx-security-lab-control-plane']
    containers=json.loads(run(node+['crictl','ps','-o','json']).stdout)['containers']
    results=[]
    for deployment in [x for x in expected['items'] if x['kind']=='Deployment']:
        name=deployment['metadata']['name']
        desired=deployment['spec']['template']['spec'];uid=desired['securityContext']['runAsUser']
        live=json.loads(kub('-n',profile.NS,'get','deployment',name,'-o','json').stdout)
        assert live['status'].get('observedGeneration')==live['metadata']['generation']
        assert live['status'].get('availableReplicas')==live['spec'].get('replicas',1)==1
        kub('apply','--dry-run=server','-f','-',doc=deployment)
        running=[c for c in containers if c['metadata']['name']==name and c['labels'].get('io.kubernetes.pod.namespace')==profile.NS]
        assert len(running)==1, 'Expected one running container: '+name
        info=json.loads(run(node+['crictl','inspect',running[0]['id']]).stdout)['info']
        runtime=info['runtimeSpec']; process=runtime['process']; pid=int(info['pid'])
        assert process['user']['uid']==process['user']['gid']==uid
        assert process['noNewPrivileges'] and runtime['root']['readonly']
        assert not any(process.get('capabilities',{}).values())
        status=dict(line.split(':',1) for line in run(node+['cat',f'/proc/{pid}/status']).stdout.splitlines() if ':' in line)
        for field,value in [('CapEff','0000000000000000'),('CapBnd','0000000000000000'),('NoNewPrivs','1'),('Seccomp','2')]:
            assert status[field].strip()==value,(name,field,status[field])
        assert set(status['Uid'].split())=={str(uid)}
        pod=json.loads(kub('-n',profile.NS,'get','pod',running[0]['labels']['io.kubernetes.pod.name'],'-o','json').stdout)
        spec=pod['spec']; desired=deployment['spec']['template']['spec']
        for field in ['serviceAccountName','automountServiceAccountToken','securityContext','volumes']:
            assert spec[field]==desired[field],(name,field)
        for field in ['securityContext','resources','volumeMounts','image']:
            assert spec['containers'][0][field]==desired['containers'][0][field],(name,field)
        actual_probe=spec['containers'][0]['readinessProbe'];desired_probe=desired['containers'][0]['readinessProbe']
        if 'httpGet' in desired_probe:
            assert actual_probe['httpGet']['path']==desired_probe['httpGet']['path']
            assert actual_probe['httpGet']['port']==desired_probe['httpGet']['port']
        else:
            assert actual_probe['exec']==desired_probe['exec']
        token=f'/proc/{pid}/root/var/run/secrets/kubernetes.io/serviceaccount/token'
        assert run(node+['test','!','-e',token],check=False).returncode==0
        sa=json.loads(kub('-n',profile.NS,'get','serviceaccount','lab-'+name,'-o','json').stdout)
        assert sa.get('automountServiceAccountToken') is False
        identity='system:serviceaccount:'+profile.NS+':lab-'+name
        for verb,resource in [('get','secrets'),('create','deployments')]:
            answer=kub('-n',profile.NS,'auth','can-i',verb,resource,'--as='+identity,
                       '--as-group=system:serviceaccounts','--as-group=system:serviceaccounts:'+profile.NS,
                       '--as-group=system:authenticated',check=False)
            assert answer.returncode==1 and answer.stdout.strip()=='no',answer.stderr
        results.append({'name':name,'pod_uid':pod['metadata']['uid'],'image':spec['containers'][0]['image'],
                        'uid':uid,'no_new_privileges':True,'effective_capabilities':'0','seccomp_mode':2,
                        'root_readonly':True,'token_absent':True,'secret_read_denied':True,'deployment_create_denied':True})
    base=next(x for x in expected['items'] if x['kind']=='Deployment' and x['metadata']['name']=={'business':'account-service','support':'edge-proxy','database':'database','observability':'grafana'}[args.profile])
    negative=[]
    cases=['root','writable-root','api-token','capability','privileged','unconfined','host-network','missing-resources','host-mount','sidecar','identity']
    if args.profile=='observability': cases += ['wrong-store','parallel-store']
    if args.profile=='database': cases += ['wrong-pvc','wrong-pgdata','parallel-database']
    for case in cases:
        d=copy.deepcopy(base); p=d['spec']['template']['spec']; c=p['containers'][0]
        if case=='root': p['securityContext']['runAsUser']=0
        elif case=='writable-root': c['securityContext']['readOnlyRootFilesystem']=False
        elif case=='api-token': p['automountServiceAccountToken']=True
        elif case=='capability': c['securityContext']['capabilities']['add']=['NET_ADMIN']
        elif case=='privileged': c['securityContext'].update(privileged=True,allowPrivilegeEscalation=True)
        elif case=='unconfined': p['securityContext']['seccompProfile']['type']='Unconfined'
        elif case=='host-network': p['hostNetwork']=True
        elif case=='missing-resources': c['resources']={}
        elif case=='host-mount': p['volumes'][0]={'name':p['volumes'][0]['name'],'hostPath':{'path':'/tmp'}}
        elif case=='sidecar': p['containers'].append({'name':'extra','image':c['image']})
        elif case=='identity': p['serviceAccountName']='default'
        elif case=='wrong-pvc': p['volumes'][0]['persistentVolumeClaim']['claimName']='unreviewed-volume'
        elif case=='wrong-store': p['volumes'][1]['persistentVolumeClaim']['claimName']='unreviewed-volume'
        elif case=='parallel-store': d['spec']['replicas']=2
        elif case=='parallel-database': d['spec']['replicas']=2
        elif case=='wrong-pgdata':
            for env in c['env']:
                if env['name']=='PGDATA': env['value']='/tmp/disposable-data'
        reply=kub('apply','--dry-run=server','-f','-',doc=d,check=False)
        denied_by=profile.POLICY if profile.POLICY in reply.stderr and 'WL:' in reply.stderr else database_permissions.POLICY if case in ['sidecar','wrong-pgdata'] and database_permissions.POLICY in reply.stderr and 'SQL:' in reply.stderr else None
        assert reply.returncode!=0 and denied_by,(case,reply.stderr)
        negative.append({'case':case,'denied_by':denied_by})
    pod_checks=[]
    if args.profile in ['support','database','observability']:
        groups=[observability_workloads] if args.profile=='observability' else [database_workload] if args.profile=='database' else [workloads,support_workloads]
        for group in groups:
            expected_policy=(group.pod_admission() if group in [database_workload,observability_workloads] else support_workloads.pod_admission(group.admission(),group.NAMES))[0]
            policy_name=expected_policy['metadata']['name']
            actual_policy=json.loads(kub('get','validatingadmissionpolicy',policy_name,'-o','json').stdout)
            assert actual_policy['spec']['validations']==expected_policy['spec']['validations']
            assert actual_policy['spec']['matchConditions']==expected_policy['spec']['matchConditions']
            assert actual_policy['spec']['failurePolicy']=='Fail'
            assert not actual_policy.get('status',{}).get('typeChecking',{}).get('expressionWarnings')
            actual_binding=json.loads(kub('get','validatingadmissionpolicybinding',policy_name,'-o','json').stdout)
            assert actual_binding['spec']=={'policyName':policy_name,'validationActions':['Deny']}
            name='grafana' if group is observability_workloads else 'database' if group is database_workload else ('edge-proxy' if group is support_workloads else 'account-service')
            dep=json.loads(kub('-n',profile.NS,'get','deployment',name,'-o','json').stdout)
            template=dep['spec']['template']
            safe={'apiVersion':'v1','kind':'Pod','metadata':{'name':'lab-admission-'+uuid.uuid4().hex[:8],'namespace':profile.NS,'labels':template['metadata']['labels']},'spec':template['spec']}
            kub('create','--dry-run=server','-f','-',doc=safe)
            for case in ['root','missing-label','default-identity']:
                unsafe=copy.deepcopy(safe)
                if case=='root': unsafe['spec']['securityContext']['runAsUser']=0
                elif case=='missing-label': unsafe['metadata'].pop('labels')
                else: unsafe['spec']['serviceAccountName']='default'
                reply=kub('create','--dry-run=server','-f','-',doc=unsafe,check=False)
                denied_by=policy_name if policy_name in reply.stderr and 'WL:' in reply.stderr else database_permissions.POLICY+'-pods' if case=='missing-label' and database_permissions.POLICY+'-pods' in reply.stderr and 'WL:' in reply.stderr else 'Pod Security Admission restricted:v1.35' if case=='root' and 'violates PodSecurity' in reply.stderr and 'restricted:v1.35' in reply.stderr else None
                assert reply.returncode!=0 and denied_by,(name,case,reply.stderr)
                pod_checks.append({'workload':name,'case':case,'denied_by':denied_by})
            live_pods=json.loads(kub('-n',profile.NS,'get','pods','-l','app='+name,'-o','json').stdout)['items']
            assert len(live_pods)==1
            debug=copy.deepcopy(live_pods[0]); pod_name=debug['metadata']['name']
            debug['spec']['ephemeralContainers']=[{'name':'lab-dry-run-debug','image':debug['spec']['containers'][0]['image'],'command':['true']}]
            reply=kub('replace','--raw',f'/api/v1/namespaces/{profile.NS}/pods/{pod_name}/ephemeralcontainers?dryRun=All','-f','-',doc=debug,check=False)
            denied_by=policy_name if policy_name in reply.stderr and 'WL:' in reply.stderr else 'Pod Security Admission restricted:v1.35' if 'violates PodSecurity' in reply.stderr and 'restricted:v1.35' in reply.stderr else None
            assert reply.returncode!=0 and denied_by,(name,'ephemeral',reply.stderr)
            pod_checks.append({'workload':name,'case':'ephemeral-container','denied_by':denied_by})
        print(f'PASS: {len(pod_checks)} direct-Pod/debug denials with valid positive controls.')
    # The selected Java/Nginx image has a shell; distroless images use CRI above.
    marker='lab-write-'+uuid.uuid4().hex
    script='set -eu; touch /tmp/'+marker+'; rm /tmp/'+marker+'; if touch /'+marker+' 2>/tmp/'+marker+'; then rm /'+marker+'; exit 1; fi; cat /tmp/'+marker+'; rm /tmp/'+marker
    probe=kub('-n',profile.NS,'exec','deployment/'+base['metadata']['name'],'--','sh','-c',script)
    assert 'Read-only file system' in probe.stdout,probe.stdout
    result={'scenario':args.profile+'-workloads','status':'passed','recorded_at':datetime.now(timezone.utc).isoformat(),
            'workloads':results,'admission_checks':negative,'pod_admission_checks':pod_checks,'root_write_denied':True,'tmp_write_passed':True,
            'source_hashes':{name:hashlib.sha256((Path(__file__).parent/name).read_bytes()).hexdigest() for name in ['workloads.py','support_workloads.py','database_workload.py','migrate-database.py','verify_workloads.py','apply-workloads.py','observability_workloads.py','observability_migration.py','migrate-observability.py','enforce-restricted.py']},
            'manifest_sha256':hashlib.sha256(json.dumps(expected,sort_keys=True).encode()).hexdigest(),
            'limitations':['Named workloads only; no namespace-wide admission claim.',
                           'Trading smoke is a separate positive control.', 'No DB/NATS authorization or runtime detection claim.']}
    if args.profile=='database':
        state_path=root/'database-migration/state.json'
        state=json.loads(state_path.read_text())
        assert state['phase']=='complete' and state['persistence_verified']
        assert state['pod_before_restart']!=state['pod_after_restart']
        backup=root/'database-migration/database.dump'
        assert hashlib.sha256(backup.read_bytes()).hexdigest()==state['backup_sha256']
        claim=json.loads(kub('-n',profile.NS,'get','pvc',database_workload.PVC,'-o','json').stdout)
        assert claim['status']['phase']=='Bound'
        pgdata=kub('-n',profile.NS,'exec','deployment/database','--','psql','-U','traderx','-d','traderx','-Atc','SHOW data_directory').stdout.strip()
        assert pgdata=='/var/lib/postgresql/data/pgdata'
        result['storage']={'pvc':database_workload.PVC,'pvc_uid':claim['metadata']['uid'],'bound':True,'pgdata':pgdata,
            'historical_restart_recovery_verified':True,'migration_completed_at':state['completed_at'],
            'migration_state_sha256':hashlib.sha256(state_path.read_bytes()).hexdigest(),'backup_sha256':state['backup_sha256'],
            'note':'Historical recovery proof; current data may legitimately change through trading. Local PVC does not survive cluster loss.'}
    if args.profile=='observability':
        state_path=root/'observability-migration/state.json';state=json.loads(state_path.read_text())
        assert state['complete']; stores=[]
        for name in observability_workloads.NAMES:
            entry=state['stores'][name];assert entry['phase']=='complete' and entry['semantic_after']['retained_historical_data_verified']
            assert entry['old_pod_uid']!=entry['new_pod_uid']
            backup=root/'observability-migration'/(name+'.tar')
            assert hashlib.sha256(backup.read_bytes()).hexdigest()==entry['archive_sha256']
            pvc=json.loads(kub('-n',profile.NS,'get','pvc','lab-'+name+'-data','-o','json').stdout)
            assert pvc['status']['phase']=='Bound'
            stores.append({'name':name,'pvc':pvc['metadata']['name'],'bound':True,'verified_files':entry['file_count'],'historical_check':entry['semantic_after']['check'],'migration_completed_at':entry['completed_at']})
        result['stores']=stores
        result['migration_state_sha256']=hashlib.sha256(state_path.read_bytes()).hexdigest()
        result['limitations'].append('Historical cutover proof; local PVCs and private checkpoints do not survive cluster/host loss together. Ingestion gaps or replay can occur.')
    args.output_dir.mkdir(parents=True,exist_ok=True)
    (args.output_dir/{'business':'workloads-result.json','support':'support-workloads-result.json','database':'database-workload-result.json','observability':'observability-result.json'}[args.profile]).write_text(json.dumps(result,indent=2)+'\n')
    print(f'PASS: {len(results)} live processes, {len(negative)} deployment denials, scoped RBAC denials, read-only root and writable tmp.')

if __name__=='__main__': main()
