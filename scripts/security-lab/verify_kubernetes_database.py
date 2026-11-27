"""Live owned-namespace database lifecycle acceptance; never removes PVCs or Secrets."""
import argparse
import json
from pathlib import Path
from unittest.mock import patch

import bootstrap_database
import credential_store
import database_lifecycle as lifecycle
from resource_operation import operation


def campaign(api, reference, credentials):
    if api.get('namespace',api.namespace) is not None:
        raise ValueError('Fresh campaign requires an absent namespace; existing evidence/data retained')
    original=bootstrap_database.render
    def broken(*args):
        return original(*args).replace('COMMIT;\n','SELECT 1/0;\nCOMMIT;\n')
    try:
        with patch.object(bootstrap_database,'render',side_effect=broken):
            lifecycle.start(api,reference,credentials)
    except RuntimeError:
        deployment=api.get('deployment','database',api.namespace)
        if deployment is None or deployment['spec']['replicas']!=0:
            raise RuntimeError('Failed initialization did not leave database stopped') from None
    else:
        raise RuntimeError('Injected SQL failure unexpectedly succeeded')
    if lifecycle.start(api,reference,credentials)!='initialized':
        raise RuntimeError('Fresh initialization after rollback failed')
    admin=credentials['bootstrap']
    def sql(text):return api.sql(admin['username'],admin['password'],text).strip()
    sql('CREATE TABLE lab_lifecycle.restart_canary(id int PRIMARY KEY); INSERT INTO lab_lifecycle.restart_canary VALUES(19);')
    pvc=api.get('persistentvolumeclaim','lab-postgresql-data',api.namespace)
    if pvc['status']['phase']!='Bound':raise RuntimeError('PVC not bound')
    secret_uids={}
    for doc in lifecycle.resources(reference,credentials,api.namespace):
        if doc['kind']=='Secret':
            obj=api.get('secret',doc['metadata']['name'],api.namespace)
            if not obj.get('immutable'):raise RuntimeError('Mutable SQL Secret')
            secret_uids[doc['metadata']['name']]=obj['metadata']['uid']
    def rows():
        return {t:sql(f"SELECT count(*),COALESCE(md5(string_agg(x::text,'' ORDER BY x::text)),'empty') FROM (SELECT to_jsonb(t) x FROM {t} t) s;")
                for t in ('accounts','accountusers','positions','trades','orderbook')}
    baseline=rows()
    pods=[]
    for _ in range(2):
        pod_list=json.loads(api.run(['get','pods','-n',api.namespace,'-l','app=database','-o','json']))
        if len(pod_list['items'])!=1:raise RuntimeError('Expected one database pod')
        pods.append(pod_list['items'][0]['metadata']['uid'])
        lifecycle.stop(api,credentials)
        if lifecycle.start(api,reference,credentials)!='resumed':raise RuntimeError('Restart reseeded')
        if rows()!=baseline or sql('SELECT id FROM lab_lifecycle.restart_canary;')!='19':
            raise RuntimeError('Restart changed committed data')
        if api.get('persistentvolumeclaim','lab-postgresql-data',api.namespace)['metadata']['uid']!=pvc['metadata']['uid']:
            raise RuntimeError('Restart replaced PVC')
        for name,uid in secret_uids.items():
            if api.get('secret',name,api.namespace)['metadata']['uid']!=uid:raise RuntimeError('Restart replaced Secret')
    pod_list=json.loads(api.run(['get','pods','-n',api.namespace,'-l','app=database','-o','json']))
    pods.append(pod_list['items'][0]['metadata']['uid'])
    if len(set(pods))!=3:raise RuntimeError('Pod recreation not observed')
    lifecycle.stop(api,credentials)
    lifecycle.stop(api,credentials)  # Idempotent stop with no pods.
    return {'status':'passed','scope':'Live Kubernetes database-only lifecycle',
        'namespace':api.namespace,'cluster_uid':api.cluster_uid,'pvc_uid':pvc['metadata']['uid'],
        'pod_uids':pods,'immutable_secret_count':len(secret_uids),'restarts':2,
        'injected_transaction_failure_recovered':True,'canary_preserved':True,
        'seed_fingerprints':baseline,'final_state':'database stopped; PVC and five Secrets retained',
        'limitations':['No application, telemetry, business authorization or trading acceptance in this campaign.']}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for arg in ('runtime-dir','store','kubeconfig','output'):parser.add_argument('--'+arg,type=Path,required=True)
    for arg in ('context','cluster-uid','namespace'):parser.add_argument('--'+arg,required=True)
    args=parser.parse_args()
    if args.output.exists():raise ValueError('Evidence output exists')
    with operation(args.runtime_dir,'acceptance'):
        credentials=credential_store.load(args.store)
        api=lifecycle.Kubernetes(args.kubeconfig,args.context,args.cluster_uid,args.namespace)
        result=campaign(api,bootstrap_database.pinned_reference(),credentials)
        with args.output.open('x') as target:json.dump(result,target,indent=2);target.write('\n')
    print('Live Kubernetes database initialization, failure recovery and two pod recreations passed.')


if __name__=='__main__':main()
