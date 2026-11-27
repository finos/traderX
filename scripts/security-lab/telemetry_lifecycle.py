"""Fresh telemetry storage and isolated collector lifecycle; never restores or erases data."""
import argparse
import copy
import hashlib
import json
from pathlib import Path

import bootstrap_database
import collector_boundary as collector
import storage_preflight
import credential_store
import database_lifecycle as db
import observability_workloads as obs
import trading_lifecycle
from resource_operation import operation, operation_lock
from resource_preflight import require

ORDER=['loki','tempo','prometheus','grafana']
DISABLED='traderx.finos.org/collector-disabled'


def infra_namespace(namespace):
    if not namespace.startswith(db.NS+'-'):raise ValueError('Telemetry requires a separate candidate namespace')
    return namespace.replace(db.NS,collector.INFRA,1)


def resources(reference,credentials,namespace):
    infra=infra_namespace(namespace);suffix=namespace[len(db.NS)+1:];owner=db.identity(credentials)
    configs={cm for group in obs.CONFIGS.values() for _,cm,_,_ in group}
    docs=[copy.deepcopy(d) for d in reference['items'] if (d['kind']=='ConfigMap' and d['metadata']['name'] in configs) or (d['kind']=='Service' and d['metadata']['name'] in ORDER)]
    docs+=obs.render(reference)['items']+collector.render(reference)['items']
    docs += [d for d in trading_lifecycle.resources(reference,credentials,namespace) if d['metadata']['name'] in ('otel-collector','lab-otel-collector','observability-otel-collector-config')]
    docs.append({'apiVersion':'v1','kind':'ServiceAccount','metadata':{'name':'lab-telemetry-init','namespace':namespace},'automountServiceAccountToken':False})
    for doc in docs:
        meta=doc['metadata'];meta.setdefault('labels',{})[db.OWNER]=owner
        if meta.get('namespace')==obs.NS:meta['namespace']=namespace
        elif meta.get('namespace')==collector.INFRA:meta['namespace']=infra
        kind=doc['kind']
        if kind=='Service':doc['spec']['type']='ClusterIP'
        if kind=='Namespace':meta['name']=infra
        if kind=='Deployment':
            doc['spec']['replicas']=0
            doc['spec']['template']['metadata'].setdefault('labels',{})[db.OWNER]=owner
        if kind=='DaemonSet':
            doc['spec']['template']['metadata'].setdefault('labels',{})[db.OWNER]=owner
            doc['spec']['template']['spec']['nodeSelector']={DISABLED:owner}
        if kind=='ConfigMap':
            doc['data']={k:v.replace(collector.APP,namespace) for k,v in doc['data'].items()}
        if kind in ('ValidatingAdmissionPolicy','ValidatingAdmissionPolicyBinding','ClusterRole','ClusterRoleBinding'):
            meta['name']+='-'+suffix
        if kind=='ValidatingAdmissionPolicy':
            doc['spec']=json.loads(json.dumps(doc['spec']).replace(collector.INFRA,infra).replace(obs.NS,namespace))
        if kind=='ValidatingAdmissionPolicyBinding':doc['spec']['policyName']+='-'+suffix
        if kind=='ClusterRoleBinding':
            doc['roleRef']['name']+='-'+suffix
            for subject in doc['subjects']:subject['namespace']=infra
    return docs


def storage_job(reference,credentials,namespace,name):
    if name not in obs.NAMES:raise ValueError('Unreviewed telemetry component')
    image=next(d for d in reference['items'] if d['kind']=='Deployment' and d['metadata']['name']=='grafana')['spec']['template']['spec']['containers'][0]['image']
    owner=db.identity(credentials)
    binding=hashlib.sha256(credential_store.encoded({'owner':owner,'paths':obs.PATHS[name],'schema':1})).hexdigest()
    # Refuse foreign/partial storage; mkdir only creates reviewed subdirectories and never removes files.
    paths=' '.join('/store'+p for p in obs.PATHS[name])
    script=f'''set -eu
if [ -e /store/.state019 ]; then
  [ "$(cat /store/.state019)" = "{binding}" ] || exit 41
else
  [ -z "$(ls -A /store)" ] || exit 42
fi
for directory in {paths}; do
  mkdir -p "$directory"
  [ -O "$directory" ] && [ -w "$directory" ] || exit 43
done
if [ ! -e /store/.state019 ]; then
  (set -C; printf '%s' '{binding}' > /store/.state019)
fi
'''
    return {'apiVersion':'batch/v1','kind':'Job','metadata':{'name':'lab-init-'+name,'namespace':namespace,'labels':{db.OWNER:owner}},
        'spec':{'backoffLimit':0,'activeDeadlineSeconds':120,'template':{'metadata':{'labels':{db.OWNER:owner}},'spec':{
            'serviceAccountName':'lab-telemetry-init','automountServiceAccountToken':False,'restartPolicy':'Never',
            'securityContext':{'runAsNonRoot':True,'runAsUser':10001,'runAsGroup':10001,'fsGroup':10001,'seccompProfile':{'type':'RuntimeDefault'}},
            'containers':[{'name':'initialize','image':image,'command':['sh','-c',script],
                'securityContext':{'allowPrivilegeEscalation':False,'readOnlyRootFilesystem':True,'capabilities':{'drop':['ALL']}},
                'resources':{'requests':{'cpu':'10m','memory':'16Mi'},'limits':{'cpu':'100m','memory':'64Mi'}},
                'volumeMounts':[{'name':'store','mountPath':'/store'}]}],
            'volumes':[{'name':'store','persistentVolumeClaim':{'claimName':'lab-'+name+'-data'}}]}}}}


def owned(api,credentials,kind,name,namespace=None):
    current=api.get(kind,name,namespace)
    if current and current['metadata'].get('labels',{}).get(db.OWNER)!=db.identity(credentials):
        raise ValueError('Refusing foreign telemetry resource')
    return current


def collector_switch(api,credentials,enabled):
    infra=infra_namespace(api.namespace)
    namespace=owned(api,credentials,'namespace',infra)
    if namespace is None:raise ValueError('Missing owned collector namespace')
    ds=owned(api,credentials,'daemonset','promtail',infra)
    if ds is None:return
    selector={} if enabled else {DISABLED:db.identity(credentials)}
    nodes=json.loads(api.run(['get','nodes','-o','json']))['items']
    if not enabled and any(n['metadata'].get('labels',{}).get(DISABLED)==db.identity(credentials) for n in nodes):
        raise ValueError('Collector stop selector matches a node')
    patch=[{'op':'test','path':'/metadata/uid','value':ds['metadata']['uid']},
           {'op':'test','path':'/metadata/resourceVersion','value':ds['metadata']['resourceVersion']},
           {'op':'add','path':'/spec/template/spec/nodeSelector','value':selector}]
    api.run(['patch','daemonset','promtail','-n',infra,'--type=json','-p',json.dumps(patch)])
    if enabled:api.run(['rollout','status','daemonset/promtail','-n',infra,'--timeout=120s'])
    else:
        pods=json.loads(api.run(['get','pods','-n',infra,'-l',db.OWNER+'='+db.identity(credentials),'-o','json']))['items']
        if pods:api.run(['wait','--for=delete','pod','-n',infra,'-l',db.OWNER+'='+db.identity(credentials),'--timeout=120s'])


def start(api,reference,credentials,runtime):
    db.namespace(api,db.identity(credentials))
    docs=resources(reference,credentials,api.namespace);missing=[]
    for doc in docs:
        meta=doc['metadata'];current=owned(api,credentials,doc['kind'],meta['name'],meta.get('namespace'))
        if current is None:missing.append(doc);continue
        expected=copy.deepcopy(doc)
        if doc['kind']=='Deployment':expected['spec'].pop('replicas')
        if doc['kind']=='DaemonSet':expected['spec']['template']['spec'].pop('nodeSelector')
        if not db.contains(current,expected):raise ValueError('Telemetry resource drift; explicit migration required')
    for name in ORDER:
        pvc=api.get('pvc','lab-'+name+'-data',api.namespace)
        if not pvc and (api.get('deployment',name,api.namespace) or api.get('job','lab-init-'+name,api.namespace)):
            raise ValueError('Telemetry storage missing beneath existing resources')
    # Admission must protect the exception namespace before its collector can run.
    priority={'Namespace':0,'ValidatingAdmissionPolicy':1,'ValidatingAdmissionPolicyBinding':2,'DaemonSet':9}
    for doc in sorted(missing,key=lambda d:priority.get(d['kind'],3)):api.create(doc)
    for name in ORDER:
        require(runtime,'acceptance')
        job=storage_job(reference,credentials,api.namespace,name)
        current=owned(api,credentials,'job',job['metadata']['name'],api.namespace)
        if current is None:api.create(job)
        elif not db.contains(current['spec']['template']['spec'],job['spec']['template']['spec']):
            raise ValueError('Storage initializer drift')
        api.run(['wait','--for=condition=complete','job/'+job['metadata']['name'],'-n',api.namespace,'--timeout=120s'])
        db.scale(api,credentials,1,name)
        api.run(['rollout','status','deployment/'+name,'-n',api.namespace,'--timeout=180s'])
        print(name+': initialized and ready',flush=True)
    db.scale(api,credentials,1,'otel-collector')
    api.run(['rollout','status','deployment/otel-collector','-n',api.namespace,'--timeout=120s'])
    collector_switch(api,credentials,True)
    print('Isolated collector: ready',flush=True)


def stop(api,credentials):
    db.namespace(api,db.identity(credentials))
    if owned(api,credentials,'namespace',infra_namespace(api.namespace)):
        collector_switch(api,credentials,False)
    for name in ['otel-collector']+list(reversed(ORDER)):
        if owned(api,credentials,'deployment',name,api.namespace):db.scale(api,credentials,0,name)
    pods=json.loads(api.run(['get','pods','-n',api.namespace,'-o','json']))['items']
    names=[p['metadata']['name'] for p in pods if p['metadata'].get('labels',{}).get('app') in ORDER+['otel-collector'] and p['metadata'].get('labels',{}).get(db.OWNER)==db.identity(credentials)]
    if names:api.run(['wait','--for=delete','-n',api.namespace,'--timeout=120s']+['pod/'+n for n in names])


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=['start','stop'])
    for arg in ('store','runtime-dir','kubeconfig'):parser.add_argument('--'+arg,type=Path,required=True)
    for arg in ('context','cluster-uid','namespace'):parser.add_argument('--'+arg,required=True)
    args=parser.parse_args();credentials=credential_store.load(args.store)
    api=db.Kubernetes(args.kubeconfig,args.context,args.cluster_uid,args.namespace)
    with (operation(args.runtime_dir,'acceptance') if args.action=='start' else operation_lock(args.runtime_dir)):
        if args.action=='stop':stop(api,credentials)
        else:
            storage_preflight.require_node(args.runtime_dir)
            try:start(api,bootstrap_database.pinned_reference(),credentials,args.runtime_dir)
            except BaseException:
                stop(api,credentials)
                raise
    print('Telemetry '+args.action+' complete; retained PVCs are never reset.')


if __name__=='__main__':main()
