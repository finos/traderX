"""Hosted-only Kubernetes schema/admission campaign; never activate application images."""
import argparse
import copy
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import uuid

import admission_fixture
import integrated_deployment as compiler
import portability
from resource_operation import operation

TOOLS=compiler.STATE/'system/admission-tools.lock.json'
FIXTURE_GATE='traderx.security-lab/admission-only'


def execute(argv,env=None,data=None,timeout=90):
    return subprocess.run(argv,env=env,input=data,capture_output=True,text=True,timeout=timeout)


def checked(argv,**kwargs):
    result=execute(argv,**kwargs)
    if result.returncode:raise RuntimeError('Owned admission fixture command failed; private command output withheld')
    return result.stdout.strip()


def guard(kind,runtime):
    if (not portability.isolated_linux() or platform.system()!='Linux' or platform.machine() not in ('x86_64','amd64')
            or os.environ.get('GITHUB_ACTIONS')!='true' or os.environ.get('RUNNER_OS')!='Linux'):
        raise ValueError('Admission campaign requires an explicitly isolated GitHub Linux AMD64 runner')
    kind=Path(kind);pins=compiler.read_json(TOOLS)
    if not kind.is_absolute() or not kind.is_file() or not os.access(kind,os.X_OK) or hashlib.sha256(kind.read_bytes()).hexdigest()!=pins['kind']['sha256']:
        raise ValueError('Pinned kind executable required')
    if shutil.disk_usage(runtime).free<6*1024**3:raise ValueError('Admission fixture requires 6 GiB disk headroom')
    available={k:int(v.split()[0])*1024 for k,_,v in (line.partition(':') for line in Path('/proc/meminfo').read_text().splitlines()) if k=='MemAvailable'}
    if available.get('MemAvailable',0)<4*1024**3:raise ValueError('Admission fixture requires 4 GiB available host memory')
    return pins


def owned_nodes(docker,name,env):
    ids=checked(docker+['ps','-aq','--filter','label=io.x-k8s.kind.cluster='+name],env=env).split()
    if len(ids)>1:raise RuntimeError('Unexpected multiple nodes in single-node admission fixture')
    if not ids:return []
    info=json.loads(checked(docker+['inspect',ids[0]],env=env))[0]
    labels=info['Config'].get('Labels',{})
    if labels.get('io.x-k8s.kind.cluster')!=name or labels.get('io.x-k8s.kind.role')!='control-plane' or info['Name']!='/'+name+'-control-plane':
        raise RuntimeError('Admission fixture ownership mismatch')
    return [info]


class API:
    def __init__(self,docker,container,env):self.docker=docker;self.container=container;self.env=env
    def call(self,args,obj=None):
        return execute(self.docker+['exec','-i',self.container,'kubectl','--kubeconfig=/etc/kubernetes/admin.conf','--request-timeout=20s']+args,
            env=self.env,data=None if obj is None else json.dumps(obj),timeout=45)
    def require(self,args,obj=None):
        result=self.call(args,obj)
        if result.returncode:raise RuntimeError('Kubernetes fixture operation failed: '+result.stderr[-4000:])
        return json.loads(result.stdout) if result.stdout.strip() else None


@contextmanager
def cluster(kind,runtime,pins):
    name='traderx-admission-'+uuid.uuid4().hex[:12]
    docker=portability.docker(runtime)
    env=dict(os.environ,DOCKER_HOST='unix:///var/run/docker.sock',DOCKER_CONFIG=str(runtime/'docker-client'),KIND_EXPERIMENTAL_PROVIDER='docker')
    for key in ('DOCKER_CONTEXT','DOCKER_TLS_VERIFY','DOCKER_CERT_PATH','KIND_EXPERIMENTAL_DOCKER_NETWORK'):env.pop(key,None)
    with tempfile.TemporaryDirectory(prefix='kind-admission-',dir=runtime) as temp:
        private=Path(temp);kubeconfig=private/'kubeconfig';env['KUBECONFIG']=str(kubeconfig)
        config=private/'kind.json'
        config.write_text(json.dumps({'kind':'Cluster','apiVersion':'kind.x-k8s.io/v1alpha4',
            'networking':{'apiServerAddress':'127.0.0.1'},'nodes':[{'role':'control-plane','image':pins['node_image']}]}))
        if owned_nodes(docker,name,env):raise ValueError('Refusing an existing fixture node')
        attempted=False
        try:
            attempted=True
            checked([str(kind),'create','cluster','--name',name,'--config',str(config),'--kubeconfig',str(kubeconfig),'--wait','120s'],env=env,timeout=300)
            nodes=owned_nodes(docker,name,env)
            if len(nodes)!=1 or nodes[0]['Config']['Image']!=pins['node_image']:raise RuntimeError('Pinned owned node not established')
            container=nodes[0]['Id']
            checked(docker+['update','--memory','3g','--memory-swap','3g','--cpus','2',container],env=env)
            api=API(docker,container,env)
            version=api.require(['get','--raw','/version'])
            if version.get('gitVersion')!=pins['kubernetes_version']:raise RuntimeError('Unexpected Kubernetes server version')
            yield api,{'kind_sha256':pins['kind']['sha256'],'node_image':pins['node_image'],
                       'kubernetes_version':version['gitVersion'],'node_memory_limit_bytes':3*1024**3}
        finally:
            if attempted:
                nodes=owned_nodes(docker,name,env)
                if nodes:
                    checked([str(kind),'delete','cluster','--name',name,'--kubeconfig',str(kubeconfig)],env=env,timeout=120)
                if owned_nodes(docker,name,env):raise RuntimeError('Owned admission node cleanup incomplete')


def pod(deployment,name=None):
    return {'apiVersion':'v1','kind':'Pod','metadata':{'name':name or deployment['metadata']['name']+'-probe',
        'namespace':deployment['metadata']['namespace'],'labels':copy.deepcopy(deployment['spec']['template']['metadata']['labels'])},
        'spec':copy.deepcopy(deployment['spec']['template']['spec'])}


def mutation(value,case):
    value=copy.deepcopy(value);p=value['spec'] if value['kind']=='Pod' else value['spec']['template']['spec'];c=p['containers'][0]
    if case=='unapproved image':c['image']='example.invalid/admission-only/unapproved@sha256:'+'f'*64
    elif case=='unapproved command':c['command']=['/unapproved/command']
    elif case=='foreign service account':p['serviceAccountName']='lab-people-service'
    elif case=='foreign private secret':next(v for v in p['volumes'] if v['name']=='runtime')['secret']['secretName']='private-people-service'
    elif case=='optional private secret':next(v for v in p['volumes'] if v['name']=='runtime')['secret']['optional']=True
    elif case=='automatic API token':p['automountServiceAccountToken']=True
    elif case=='writable root filesystem':c['securityContext']['readOnlyRootFilesystem']=False
    elif case=='unbounded memory profile':c['resources']['limits']['memory']='2Gi'
    else:raise ValueError('Unknown admission mutation')
    return value


def denied(result,policy):
    message=result.stdout+'\n'+result.stderr
    return result.returncode!=0 and policy in message and 'Integrated application contract required' in message and 'denied request' in message


def typechecked(api,policy,deadline):
    while time.monotonic()<deadline:
        value=api.require(['get','validatingadmissionpolicy',policy,'-o','json'])
        status=value.get('status',{})
        if status.get('observedGeneration')==value['metadata']['generation'] and 'typeChecking' in status:
            warnings=status['typeChecking'].get('expressionWarnings',[])
            if warnings:raise RuntimeError('Admission CEL type checking failed: '+json.dumps(warnings))
            return
        time.sleep(.25)
    raise RuntimeError('Admission type checking timed out')


def delete_probe(api,name,namespace):
    # kubectl delete supports name output, not JSON. Check its exit status, then
    # independently read the API to establish absence rather than trusting text.
    result=api.call(['delete','pod',name,'-n',namespace,'--wait=true','--timeout=30s','-o','name'])
    if result.returncode:raise RuntimeError('Ephemeral probe deletion failed: '+result.stderr[-3000:])
    remaining=api.require(['get','pod',name,'-n',namespace,'--ignore-not-found','-o','json'])
    if remaining is not None:raise RuntimeError('Ephemeral probe remains after deletion')


def campaign(api,documents):
    checks=[];namespace=admission_fixture.NAMESPACE
    def passed(name):checks.append(name);print(name+': passed',file=sys.stderr,flush=True)
    namespaces=[d for d in documents if d['kind']=='Namespace']
    for doc in namespaces:api.require(['create','-f','-','-o','json'],doc)
    for doc in documents:
        if doc['kind']=='ServiceAccount':api.require(['create','-f','-','-o','json'],doc)
    policies=[d for d in documents if d['kind']=='ValidatingAdmissionPolicy']
    for doc in policies:
        api.require(['create','-f','-','-o','json'],doc)
        typechecked(api,doc['metadata']['name'],time.monotonic()+45)
        passed(doc['metadata']['name']+' schema and CEL types accepted')
    for doc in documents:
        if doc['kind']=='ValidatingAdmissionPolicyBinding':api.require(['create','-f','-','-o','json'],doc)
    deployments=[d for d in documents if d['kind']=='Deployment']
    candidate=next(d for d in deployments if d['metadata']['name']=='browser-session')
    policy=namespace+'-images-deployments'
    deadline=time.monotonic()+30
    while True:
        response=api.call(['create','--dry-run=server','-f','-','-o','json'],mutation(candidate,'unapproved image'))
        if denied(response,policy):break
        if response.returncode:raise RuntimeError('Admission readiness failed outside intended policy: '+response.stderr[-3000:])
        if time.monotonic()>=deadline:raise RuntimeError('Admission binding did not become active')
        time.sleep(.25)
    passed('admission binding actively rejects an unapproved deployment image')
    for doc in documents:
        if doc['kind'] in ('Service','NetworkPolicy'):
            api.require(['create','--dry-run=server','-f','-','-o','json'],doc)
    passed('ClusterIP services and complete NetworkPolicy inventory pass server schema validation')
    for doc in deployments:
        api.require(['create','--dry-run=server','-f','-','-o','json'],doc)
        api.require(['create','--dry-run=server','-f','-','-o','json'],pod(doc))
        passed(doc['metadata']['name']+' approved Deployment and Pod admitted in dry-run')
    for template in (candidate,pod(candidate)):
        policy=namespace+'-images-'+('pods' if template['kind']=='Pod' else 'deployments')
        for case in ('unapproved image','unapproved command','foreign service account','foreign private secret',
                     'optional private secret','automatic API token','writable root filesystem','unbounded memory profile'):
            response=api.call(['create','--dry-run=server','-f','-','-o','json'],mutation(template,case))
            if not denied(response,policy):raise RuntimeError('Expected '+template['kind']+' policy denial for '+case+': '+response.stderr[-3000:])
            passed(template['kind']+' '+case+' denied by intended policy')
    # This sole persisted application-shaped object cannot be scheduled. It is
    # needed to exercise the real ephemeralcontainers update subresource.
    parked=pod(candidate,'admission-ephemeral-probe')
    parked['spec'].update(schedulerName='traderx-admission-no-scheduler',schedulingGates=[{'name':FIXTURE_GATE}])
    created=False
    try:
        api.require(['create','-f','-','-o','json'],parked);created=True
        current=api.require(['get','pod',parked['metadata']['name'],'-n',namespace,'-o','json'])
        if current['spec'].get('nodeName') or current['spec'].get('schedulingGates')!=[{'name':FIXTURE_GATE}]:
            raise RuntimeError('Ephemeral probe unexpectedly schedulable')
        extra=copy.deepcopy(current['spec']['containers'][0])
        for field in ('resources','ports','readinessProbe'):extra.pop(field,None)
        extra.update(name='unapproved-debugger',targetContainerName='browser-session')
        current['spec']['ephemeralContainers']=[extra]
        response=api.call(['replace','--raw',f'/api/v1/namespaces/{namespace}/pods/{parked["metadata"]["name"]}/ephemeralcontainers?dryRun=All','-f','-'],current)
        if not denied(response,namespace+'-images-pods'):raise RuntimeError('Ephemeral subresource denial not established: '+response.stderr[-3000:])
        unchanged=api.require(['get','pod',parked['metadata']['name'],'-n',namespace,'-o','json'])
        if unchanged['spec'].get('ephemeralContainers') or unchanged['spec'].get('nodeName') or unchanged.get('status',{}).get('containerStatuses'):
            raise RuntimeError('Admission-only probe unexpectedly changed or started')
        passed('ephemeral-container update denied and scheduling-gated Pod remains unchanged')
    finally:
        if created:delete_probe(api,parked['metadata']['name'],namespace)
    for resource in ('pods','deployments'):
        if api.require(['get',resource,'-n',namespace,'-o','json'])['items']:raise RuntimeError('Application object remains after admission probes')
    passed('no application Pod or Deployment remains or was activated')
    return checks


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-dir',required=True,type=Path);parser.add_argument('--kind',required=True,type=Path)
    parser.add_argument('--output',required=True,type=Path);args=parser.parse_args()
    os.umask(0o077)
    args.runtime_dir.mkdir(parents=True,exist_ok=True)
    if args.output.exists():raise ValueError('Choose a new admission evidence file')
    pins=guard(args.kind,args.runtime_dir)
    def stopping(*_):
        signal.signal(signal.SIGTERM,signal.SIG_IGN)
        raise KeyboardInterrupt('Stopping owned admission fixture')
    old=signal.signal(signal.SIGTERM,stopping)
    try:
        with operation(args.runtime_dir,'fixture'):
            with tempfile.TemporaryDirectory(prefix='admission-oci-',dir=args.runtime_dir) as temp:
                revision=checked(['git','-C',str(compiler.ROOT),'rev-parse','HEAD'])
                config=admission_fixture.contract(Path(temp),revision)
                files=compiler.compile_bundle(config)
                documents=json.loads(files['application-core.json'])['items']
                with cluster(args.kind,args.runtime_dir,pins) as (api,platform_result):checks=campaign(api,documents)
        result={'status':'passed','scope':'Kubernetes schema and admission only; synthetic OCI fixtures, no application runtime',
            'platform':platform_result,'checks':checks,'source_commit':revision,
            'core_manifest_sha256':compiler.sha(files['application-core.json']),
            'source_manifest_sha256':json.loads(files['plan.json'])['source_manifest']['sha256'],
            'limitations':['OCI fixtures have empty filesystems and are not application builds; they are never pushed, imported or run.',
                'Services and NetworkPolicies pass API schema checks only; no CNI flow enforcement or application TLS proof.',
                'No application activation, trading, WAF, telemetry, image-signature or complete State 019 acceptance is implied.']}
        with args.output.open('x') as target:json.dump(result,target,indent=2);target.write('\n')
        print(json.dumps(result,sort_keys=True))
    finally:signal.signal(signal.SIGTERM,old)


if __name__=='__main__':main()
