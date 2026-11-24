"""Cumulative State 019 runtime candidate; does not publish or certify the hardened state."""
import argparse
import json
from pathlib import Path

import bootstrap_database
import credential_store
import database_lifecycle as db
import database_workload
from resource_operation import operation, operation_lock
import telemetry_lifecycle
import storage_preflight
import trading_lifecycle
import verify_telemetry_lifecycle
import verify_trading_lifecycle


def database_policies(credentials,namespace):
    suffix=namespace.removeprefix(db.NS+'-')
    telemetry_lifecycle.infra_namespace(namespace)  # Require a separate candidate namespace.
    docs=database_workload.admission()+database_workload.pod_admission()
    for doc in docs:
        doc['metadata']['name']+='-'+suffix
        doc['metadata']['labels']={db.OWNER:db.identity(credentials)}
        if doc['kind']=='ValidatingAdmissionPolicy':
            doc['spec']=json.loads(json.dumps(doc['spec']).replace(db.NS,namespace))
        else:doc['spec']['policyName']+='-'+suffix
    return docs


def start(api,reference,credentials,runtime):
    db.start(api,reference,credentials)
    policies=database_policies(credentials,api.namespace)
    missing=[]
    for doc in policies:
        current=api.get(doc['kind'],doc['metadata']['name'])
        if current is None:missing.append(doc)
        elif not db.contains(current,doc):raise ValueError('Database policy differs; no replacement attempted')
    for doc in sorted(missing,key=lambda d:d['kind']=='ValidatingAdmissionPolicyBinding'):api.create(doc)
    telemetry_lifecycle.start(api,reference,credentials,runtime)
    trading_lifecycle.start(api,reference,credentials,runtime)
    ready(api,credentials)
    print('All nineteen candidate deployments and isolated collector are ready.',flush=True)


def ready(api,credentials):
    names=set(trading_lifecycle.ORDER+telemetry_lifecycle.ORDER+['database'])
    deployments=json.loads(api.run(['get','deployments','-n',api.namespace,'-o','json']))['items']
    if {d['metadata']['name'] for d in deployments}!=names or any(d.get('status',{}).get('readyReplicas')!=1 for d in deployments):
        raise RuntimeError('Full nineteen-deployment readiness not established')
    if any(d['metadata'].get('labels',{}).get(db.OWNER)!=db.identity(credentials) for d in deployments):
        raise ValueError('Foreign deployment in cumulative candidate')
    ds=api.get('daemonset','promtail',telemetry_lifecycle.infra_namespace(api.namespace))
    if ds is None or ds['metadata'].get('labels',{}).get(db.OWNER)!=db.identity(credentials):
        raise ValueError('Missing owned collector')
    status=ds.get('status',{})
    if status.get('desiredNumberScheduled',0)<1 or status.get('numberReady')!=status.get('desiredNumberScheduled'):
        raise RuntimeError('Collector readiness not established')


def stop(api,credentials):
    failures=[]
    for component in (telemetry_lifecycle,trading_lifecycle):
        try:component.stop(api,credentials)
        except Exception:failures.append(component.__name__)
    if failures:raise RuntimeError('Owned shutdown incomplete for '+','.join(failures)+'; inspect retained resources')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=['start','stop','test'])
    for arg in ('store','runtime-dir','kubeconfig'):parser.add_argument('--'+arg,type=Path,required=True)
    for arg in ('context','cluster-uid','namespace'):parser.add_argument('--'+arg,required=True)
    parser.add_argument('--output',type=Path)
    args=parser.parse_args()
    if args.action=='test' and (args.output is None or args.output.exists()):
        raise ValueError('Test requires a new evidence output filename')
    credentials=credential_store.load(args.store)
    api=db.Kubernetes(args.kubeconfig,args.context,args.cluster_uid,args.namespace)
    with (operation_lock(args.runtime_dir) if args.action=='stop' else operation(args.runtime_dir,'acceptance')):
        if args.action=='stop':stop(api,credentials)
        else:
            storage_preflight.require_node(args.runtime_dir)
            reference=bootstrap_database.pinned_reference()
            try:
                if args.action=='start':start(api,reference,credentials,args.runtime_dir)
                else:
                    ready(api,credentials)
                    result={'status':'passed','scope':'Cumulative runtime candidate; remaining security gates are not implied',
                        'telemetry':verify_telemetry_lifecycle.campaign(api,reference,credentials,args.runtime_dir),
                        'trading':verify_trading_lifecycle.campaign(api,credentials,18480)}
                    ready(api,credentials)
                    with args.output.open('x') as target:json.dump(result,target,indent=2);target.write('\n')
            except BaseException:
                stop(api,credentials)
                raise
    print('State 019 candidate '+args.action+' complete; publication/security acceptance remains separately gated.')


if __name__=='__main__':main()
