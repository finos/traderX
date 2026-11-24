"""Database-only lifecycle candidate. Never adopts, resets, or deletes existing storage."""
import argparse
import base64
import copy
import hashlib
import json
from pathlib import Path
import subprocess

import bootstrap_database
import credential_store
import database_permissions
import database_workload
from resource_operation import operation, operation_lock

NS = database_workload.NS
OWNER = 'traderx.finos.org/sql-owner'


def identity(credentials):
    return hashlib.sha256(('state019-sql-owner:' + credentials['bootstrap']['password']).encode()).hexdigest()[:32]


def binding(reference, credentials):
    return hashlib.sha256(credential_store.encoded({'owner': identity(credentials),
        'contract': credentials['contract'], 'seed': bootstrap_database.seed_sql(reference)})).hexdigest()


def initialize(sql, reference, credentials):
    """SQL callback returns rows or raises a redacted exception. Marker commits with seed."""
    admin = credentials['bootstrap']
    def query(text):
        return sql(admin['username'], admin['password'], text).strip()
    expected = binding(reference, credentials)
    marker = query("SELECT COALESCE(to_regclass('lab_lifecycle.bootstrap')::text,'');")
    if marker:
        if query('SELECT binding FROM lab_lifecycle.bootstrap;') != expected:
            raise ValueError('Database lifecycle binding mismatch; no reset attempted')
        result = 'resumed'
    else:
        transaction = bootstrap_database.render(reference, credentials['runtime'])
        marker_sql = ("CREATE SCHEMA lab_lifecycle; REVOKE ALL ON SCHEMA lab_lifecycle FROM PUBLIC;\n"
                      "CREATE TABLE lab_lifecycle.bootstrap(binding text PRIMARY KEY);\n"
                      f"INSERT INTO lab_lifecycle.bootstrap VALUES ('{expected}');\n")
        # Session settings avoid exporting statements containing generated passwords.
        query('SET log_statement=none; SET log_min_error_statement=panic;\n' +
              transaction.replace('COMMIT;\n', marker_sql + 'COMMIT;\n'))
        result = 'initialized'
    for entry in credentials['runtime'].values():
        if sql(entry['username'], entry['password'], 'SELECT current_user;').strip() != entry['username']:
            raise ValueError('Runtime credential verification failed')
    return result


def resources(reference, credentials):
    owner = identity(credentials)
    rendered = database_workload.render(reference)['items']
    items = [copy.deepcopy(d) for d in rendered if d['kind'] in ('PersistentVolumeClaim', 'ServiceAccount', 'ConfigMap')]
    deployment = database_permissions.bootstrap_deployment(reference)
    # No application is rolled out before initialization and credential checks pass.
    deployment['spec']['replicas'] = 0
    deployment['spec']['template']['metadata'].setdefault('labels', {})[OWNER] = owner
    items.append(deployment)
    for name, values in [('lab-sql-bootstrap', {'password': credentials['bootstrap']['password']})] + [
            (database_permissions.secret_name(n), v) for n, v in credentials['runtime'].items()]:
        items.insert(0, {'apiVersion':'v1','kind':'Secret','metadata':{'name':name,'namespace':NS},
            'type':'Opaque','immutable':True,
            'data':{k:base64.b64encode(v.encode()).decode() for k,v in values.items()}})
    for d in items:
        d['metadata'].setdefault('labels', {})[OWNER] = owner
    return items


def contains(actual, desired):
    """Allow API-defaulted dictionary fields; lists must retain exact reviewed members."""
    if isinstance(desired, dict):
        return isinstance(actual, dict) and all(k in actual and contains(actual[k], v) for k,v in desired.items())
    if isinstance(desired, list):
        return isinstance(actual, list) and len(actual)==len(desired) and all(contains(a,b) for a,b in zip(actual,desired))
    return actual == desired


class Kubernetes:
    def __init__(self, kubeconfig, context, cluster_uid):
        self.command = ['kubectl','--kubeconfig',str(kubeconfig),'--context',context,'--request-timeout=30s']
        self.cluster_uid = cluster_uid

    def run(self, args, input=None):
        result = subprocess.run(self.command+args, input=input, text=True, capture_output=True, timeout=180)
        if result.returncode:
            raise RuntimeError('Kubernetes database operation failed; private output withheld')
        return result.stdout

    def get(self, kind, name, namespace=None):
        args = ['get',kind,name,'--ignore-not-found','-o','json']
        if namespace: args += ['-n',namespace]
        output = self.run(args).strip()
        return json.loads(output) if output else None

    def check_cluster(self):
        if self.get('namespace','kube-system')['metadata']['uid'] != self.cluster_uid:
            raise ValueError('Cluster identity mismatch')

    def create(self, obj):
        self.run(['create','-f','-'], json.dumps(obj))

    def sql(self, role, password, text):
        shell = 'IFS= read -r PGPASSWORD; export PGPASSWORD; exec psql -X -w -h 127.0.0.1 -U "$1" -d traderx -At -v ON_ERROR_STOP=1 -v VERBOSITY=sqlstate'
        return self.run(['exec','-i','-n',NS,'deployment/database','--','sh','-c',shell,'lab-sql',role], password+'\n'+text+'\n')


def namespace(api, owner, create=False):
    api.check_cluster()
    current = api.get('namespace', NS)
    if current is None and create:
        api.create({'apiVersion':'v1','kind':'Namespace','metadata':{'name':NS,'labels':{
            OWNER:owner,'pod-security.kubernetes.io/enforce':'restricted',
            'pod-security.kubernetes.io/enforce-version':'v1.35'}}})
        current = api.get('namespace',NS)
    if current is None or current['metadata'].get('labels',{}).get(OWNER) != owner:
        raise ValueError('Refusing unowned or missing namespace')
    if current['metadata'].get('deletionTimestamp'):
        raise ValueError('Namespace is terminating')
    return current['metadata']['uid']


def scale(api, credentials, replicas):
    namespace(api,identity(credentials))
    current = api.get('deployment','database',NS)
    if current is None or current['metadata'].get('labels',{}).get(OWNER) != identity(credentials):
        raise ValueError('Refusing unowned or missing database deployment')
    # UID/resourceVersion preconditions prevent replacing an object observed earlier.
    patch = [{'op':'test','path':'/metadata/uid','value':current['metadata']['uid']},
             {'op':'test','path':'/metadata/resourceVersion','value':current['metadata']['resourceVersion']},
             {'op':'replace','path':'/spec/replicas','value':replicas}]
    api.run(['patch','deployment','database','-n',NS,'--type=json','-p',json.dumps(patch)])


def start(api, reference, credentials):
    owner = identity(credentials)
    uid = namespace(api,owner,create=True)
    desired = resources(reference,credentials)
    # Validate every existing object before creating any missing object or scaling up.
    missing = []
    deployment_exists = False
    for doc in desired:
        current = api.get(doc['kind'],doc['metadata']['name'],NS)
        if current is None:
            missing.append(doc)
            continue
        if doc['kind']=='Deployment':
            deployment_exists = True
        expected = copy.deepcopy(doc)
        if doc['kind']=='Deployment':
            expected['spec'].pop('replicas')
        if not contains(current,expected):
            raise ValueError('Existing database resource differs; no replacement attempted')
    if deployment_exists and any(doc['kind']=='PersistentVolumeClaim' for doc in missing):
        raise ValueError('Existing deployment lost its storage; explicit recovery required')
    for doc in missing:
        if namespace(api,owner) != uid:
            raise ValueError('Namespace replaced during startup')
        api.create(doc)
    scale(api,credentials,1)
    api.run(['rollout','status','deployment/database','-n',NS,'--timeout=120s'])
    try:
        return initialize(api.sql,reference,credentials)
    except Exception:
        scale(api,credentials,0)
        raise


def stop(api, credentials):
    scale(api,credentials,0)
    # Wait for pods to disappear; keep PVCs, Secrets, namespace and data intact.
    selector='app=database,'+OWNER+'='+identity(credentials)
    pods=json.loads(api.run(['get','pods','-n',NS,'-l',selector,'-o','json']))
    if pods['items']:
        api.run(['wait','--for=delete','pod','-n',NS,'-l',selector,'--timeout=120s'])
    return 'stopped-data-retained'


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=['start','stop'])
    parser.add_argument('--store',type=Path,required=True)
    parser.add_argument('--runtime-dir',type=Path,required=True)
    parser.add_argument('--kubeconfig',type=Path,required=True)
    parser.add_argument('--context',required=True)
    parser.add_argument('--cluster-uid',required=True)
    args=parser.parse_args()
    try:
        credentials=credential_store.load(args.store)
        api=Kubernetes(args.kubeconfig,args.context,args.cluster_uid)
        # Stop needs the lock and identity checks, but must remain usable under pressure.
        guard=operation(args.runtime_dir,'acceptance') if args.action=='start' else operation_lock(args.runtime_dir)
        with guard:
            result=start(api,bootstrap_database.pinned_reference(),credentials) if args.action=='start' else stop(api,credentials)
        print('Database-only lifecycle: '+result+'; full trading acceptance remains pending.')
    except (OSError,ValueError,RuntimeError,subprocess.SubprocessError):
        parser.exit(1,'Database lifecycle refused or incomplete; retained resources require inspection. Private output withheld.\n')


if __name__=='__main__': main()
