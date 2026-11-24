"""Bounded real database restart test; does not claim Kubernetes or trading acceptance."""
import argparse
import json
from pathlib import Path
import tempfile

import bootstrap_database
import credential_store
import database_lifecycle
from resource_operation import operation
from verify_bootstrap import database, fingerprint, require


def campaign(runtime):
    reference=bootstrap_database.pinned_reference()
    image=next(d for d in reference['items'] if d['kind']=='Deployment' and d['metadata']['name']=='database')['spec']['template']['spec']['containers'][0]['image']
    with tempfile.TemporaryDirectory(prefix='restart-private-',dir=runtime) as private:
        store=Path(private)/'identities'
        credential_store.create(store)
        credentials=credential_store.load(store)
        with database(runtime,image,credentials=credentials,persistent=True) as (execute,password,restart):
            def sql(role,secret,text):
                return require(execute(role,secret,text),'Lifecycle SQL verification failed')
            if database_lifecycle.initialize(sql,reference,credentials)!='initialized':
                raise RuntimeError('Expected first initialization')
            # A committed synthetic canary must survive; a reseed would erase it.
            sql('traderx',password,'CREATE TABLE lab_lifecycle.restart_canary(id int PRIMARY KEY); INSERT INTO lab_lifecycle.restart_canary VALUES (19);')
            before=fingerprint(execute,password)
            for _ in range(2):
                restart()
                loaded=credential_store.load(store)
                if loaded!=credentials:raise RuntimeError('Stored identities changed')
                if database_lifecycle.initialize(sql,reference,loaded)!='resumed':
                    raise RuntimeError('Restart unexpectedly initialized')
                if sql('traderx',password,'SELECT id FROM lab_lifecycle.restart_canary;')!='19':
                    raise RuntimeError('Committed canary lost')
                if fingerprint(execute,password)!=before:raise RuntimeError('Synthetic data changed')
            altered=dict(credentials,contract='wrong')
            try:database_lifecycle.initialize(sql,reference,altered)
            except ValueError:pass
            else:raise RuntimeError('Mismatched lifecycle contract accepted')
    return {'status':'passed','scope':'Persistent Docker database fixture; Kubernetes adapter not exercised',
        'image':image,'restarts':2,'runtime_logins_per_start':4,'seed_fingerprints':before,
        'committed_canary_preserved':True,'mismatched_binding_refused':True,
        'limits':{'memory_mib':256,'cpu':1,'host_ports':0},
        'limitations':['Does not validate PVC provisioning, Kubernetes rollout or normal trading.','Owned disposable volume removed after verification.']}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-dir',required=True,type=Path)
    parser.add_argument('--output',required=True,type=Path)
    args=parser.parse_args()
    if args.output.exists():raise ValueError('Evidence output already exists')
    with operation(args.runtime_dir,'fixture'):
        result=campaign(args.runtime_dir)
        with args.output.open('x') as target:json.dump(result,target,indent=2);target.write('\n')
    print('Persistent database initialization and two restarts passed; Kubernetes acceptance remains pending.')


if __name__=='__main__':main()
