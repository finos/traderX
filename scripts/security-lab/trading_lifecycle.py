"""Bounded trading-function candidate; telemetry persistence/full-state acceptance pending."""
import argparse
import copy
import json
from pathlib import Path

import bootstrap_database
import credential_store
import database_lifecycle as db
import database_permissions
import support_workloads
import workloads
from resource_operation import operation, operation_lock
from resource_preflight import require

ORDER = ['nats-broker','otel-collector','reference-data','people-service','account-service',
         'position-service','price-publisher','trade-processor','trade-service','order-matcher',
         'blackbox-exporter','web-front-end-angular','api-explorer','edge-proxy']


def resources(reference, credentials, namespace):
    groups=[database_permissions.transform(workloads.render(reference)),support_workloads.render(reference)]
    items=[copy.deepcopy(d) for d in reference['items'] if d['kind'] in ('Service','ConfigMap')
           and d['metadata']['name']!='database-init-sql']
    replacements={(d['kind'],d['metadata']['name']):d for group in groups for d in group['items']}
    items=[d for d in items if (d['kind'],d['metadata']['name']) not in replacements]+list(replacements.values())
    # Scoped SQL admission applies to the database as well as its four consumers.
    items+=database_permissions.admission(reference)
    owner=db.identity(credentials)
    for doc in items:
        meta=doc['metadata'];meta.setdefault('labels',{})[db.OWNER]=owner
        if 'namespace' in meta:meta['namespace']=namespace
        if doc['kind']=='Service':
            doc['spec']['type']='ClusterIP'
            doc['spec'].pop('externalTrafficPolicy',None)
            for port in doc['spec']['ports']:port.pop('nodePort',None)
        if doc['kind']=='Deployment':
            doc['spec']['replicas']=0
            doc['spec']['template']['metadata'].setdefault('labels',{})[db.OWNER]=owner
        if doc['kind'] in ('ValidatingAdmissionPolicy','ValidatingAdmissionPolicyBinding'):
            # Keep the older namespace's admission policy intact.
            meta['name']+='-'+namespace.removeprefix('traderx-security-lab').lstrip('-')
            if doc['kind']=='ValidatingAdmissionPolicy':
                doc['spec']=json.loads(json.dumps(doc['spec']).replace(workloads.NS,namespace))
            else:doc['spec']['policyName']+='-'+namespace.removeprefix('traderx-security-lab').lstrip('-')
    return items


def start(api,reference,credentials,runtime):
    db.namespace(api,db.identity(credentials))
    if api.namespace==workloads.NS:
        raise ValueError('Trading candidate requires a separate namespace')
    docs=resources(reference,credentials,api.namespace)
    missing=[]
    for doc in docs:
        current=api.get(doc['kind'],doc['metadata']['name'],doc['metadata'].get('namespace'))
        if current is None:missing.append(doc);continue
        expected=copy.deepcopy(doc)
        if doc['kind']=='Deployment':expected['spec'].pop('replicas')
        if not db.contains(current,expected):raise ValueError('Existing trading resource differs; no replacement attempted')
    for doc in sorted(missing,key=lambda d: d['kind']=='ValidatingAdmissionPolicyBinding'):
        api.create(doc)
    db.start(api,reference,credentials)
    for name in ORDER:
        require(runtime,'acceptance')
        db.scale(api,credentials,1,name)
        api.run(['rollout','status','deployment/'+name,'-n',api.namespace,'--timeout=180s'])
        print(name+': ready',flush=True)


def stop(api,credentials):
    for name in reversed(ORDER):
        current=api.get('deployment',name,api.namespace)
        if current is not None:db.scale(api,credentials,0,name)
    db.stop(api,credentials)
    selector=db.OWNER+'='+db.identity(credentials)
    pods=json.loads(api.run(['get','pods','-n',api.namespace,'-l',selector,'-o','json']))
    if pods['items']:
        api.run(['wait','--for=delete','pod','-n',api.namespace,'-l',selector,'--timeout=120s'])


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=['start','stop'])
    for arg in ('store','runtime-dir','kubeconfig'):parser.add_argument('--'+arg,type=Path,required=True)
    for arg in ('context','cluster-uid','namespace'):parser.add_argument('--'+arg,required=True)
    args=parser.parse_args()
    credentials=credential_store.load(args.store)
    api=db.Kubernetes(args.kubeconfig,args.context,args.cluster_uid,args.namespace)
    with (operation(args.runtime_dir,'acceptance') if args.action=='start' else operation_lock(args.runtime_dir)):
        if args.action=='stop':stop(api,credentials)
        else:
            try:start(api,bootstrap_database.pinned_reference(),credentials,args.runtime_dir)
            except Exception:
                stop(api,credentials)
                raise
    print('Trading candidate '+args.action+' complete; full-state acceptance remains pending.')


if __name__=='__main__':main()
