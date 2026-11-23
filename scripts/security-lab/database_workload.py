#!/usr/bin/env python3
"""Canonical PostgreSQL storage/process profile; no SQL least-privilege claim."""
import copy
import workloads as business
import support_workloads as support
NS=business.NS
NAMES=['database']
POLICY='traderx-lab-database-workload'
PVC='lab-postgresql-data'
VOLUMES=[{'name':'db-data','persistentVolumeClaim':{'claimName':PVC}},
 {'name':'lab-tmp','emptyDir':{'sizeLimit':'128Mi'}},
 {'name':'lab-socket','emptyDir':{'sizeLimit':'16Mi'}},
 {'name':'lab-bootstrap','configMap':{'name':'lab-database-bootstrap','defaultMode':420}}]
MOUNTS=[{'name':'db-data','mountPath':'/var/lib/postgresql/data'},
 {'name':'lab-tmp','mountPath':'/tmp'},
 {'name':'lab-socket','mountPath':'/var/run/postgresql'},
 {'name':'lab-bootstrap','mountPath':'/docker-entrypoint-initdb.d','readOnly':True}]


def admission():
    docs=copy.deepcopy(business.admission());policy=docs[0]
    policy['metadata']['name']=POLICY;docs[1]['metadata']['name']=POLICY;docs[1]['spec']['policyName']=POLICY
    policy['spec']['matchConditions'][0]['expression']=f'object.metadata.namespace == "{NS}" && object.metadata.name == "database"'
    checks=policy['spec']['validations'][:7]
    for check in checks: check['expression']=check['expression'].replace('10001','70')
    p='object.spec.template.spec';c=p+'.containers[0]'
    terms=[f'has({p}.volumes)',f'{p}.volumes.size() == 4',f'has({c}.volumeMounts)',f'{c}.volumeMounts.size() == 4']
    for i,v in enumerate(VOLUMES):
        a=f'{p}.volumes[{i}]';terms.append(f'{a}.name == "{v["name"]}"')
        if 'persistentVolumeClaim' in v:
            terms += [f'has({a}.persistentVolumeClaim)',f'{a}.persistentVolumeClaim.claimName == "{PVC}"']
        elif 'configMap' in v:
            terms += [f'has({a}.configMap)',f'{a}.configMap.name == "lab-database-bootstrap"']
        else:
            terms += [f'has({a}.emptyDir)',f'has(dyn({a}.emptyDir).sizeLimit)',f'dyn({a}.emptyDir).sizeLimit == "{v["emptyDir"]["sizeLimit"]}"']
    for i,m in enumerate(MOUNTS):
        a=f'{c}.volumeMounts[{i}]';terms += [f'{a}.name == "{m["name"]}"',f'{a}.mountPath == "{m["mountPath"]}"',f'!has({a}.subPath)',f'!has({a}.subPathExpr)']
        if m.get('readOnly'): terms += [f'has({a}.readOnly)',f'{a}.readOnly']
    checks.append({'expression':' && '.join(terms),'message':'WL: exact PostgreSQL PVC and writable mounts required'})
    checks.append({'expression':f'has({c}.env) && {c}.env.filter(e, e.name == "PGDATA").size() == 1 && {c}.env.exists(e, e.name == "PGDATA" && has(e.value) && e.value == "/var/lib/postgresql/data/pgdata")','message':'WL: persistent PGDATA subdirectory required'})
    checks.append({'expression':f'has({c}.resources) && has(dyn({c}.resources).requests) && has(dyn({c}.resources).limits) && dyn({c}.resources).requests == {{"cpu":"25m","memory":"64Mi"}} && dyn({c}.resources).limits == {{"cpu":"1","memory":"512Mi"}}','message':'WL: database resource bounds required'})
    checks.append({'expression':'object.spec.strategy.type == "Recreate" && object.spec.replicas <= 1','message':'WL: database requires single-server Recreate strategy'})
    policy['spec']['validations']=checks
    return docs


def pod_admission():
    docs=admission()
    docs[0]['spec']['validations']=[v for v in docs[0]['spec']['validations'] if v['message']!='WL: database requires single-server Recreate strategy']
    return support.pod_admission(docs,NAMES)


def render(reference):
    matches=[d for d in reference['items'] if d['kind']=='Deployment' and d['metadata']['name']=='database']
    if len(matches)!=1: raise ValueError('Expected one database')
    d=copy.deepcopy(matches[0]);p=d['spec']['template']['spec']
    if d['metadata']['namespace']!=NS or len(p['containers'])!=1 or p['volumes']!=[{'name':'db-data','emptyDir':{}},{'name':'database-init-sql','configMap':{'name':'database-init-sql'}}]: raise ValueError('Unreviewed database layout')
    c=p['containers'][0]
    if c['name']!='database' or '@sha256:' not in c['image']: raise ValueError('Unpinned database')
    d['spec']['strategy']={'type':'Recreate'}
    p.update(serviceAccountName='lab-database',automountServiceAccountToken=False,
      securityContext={'runAsNonRoot':True,'runAsUser':70,'runAsGroup':70,'fsGroup':70,'seccompProfile':{'type':'RuntimeDefault'}},volumes=copy.deepcopy(VOLUMES))
    c.update(securityContext={'allowPrivilegeEscalation':False,'readOnlyRootFilesystem':True,'capabilities':{'drop':['ALL']}},
      resources={'requests':{'cpu':'25m','memory':'64Mi'},'limits':{'cpu':'1','memory':'512Mi'}},volumeMounts=copy.deepcopy(MOUNTS))
    c['env']=[e for e in c.get('env',[]) if e['name']!='PGDATA']+[{'name':'PGDATA','value':'/var/lib/postgresql/data/pgdata'}]
    for kind in ['readinessProbe','livenessProbe']:
        c[kind]={'exec':{'command':['pg_isready','-U','traderx','-d','traderx']},'periodSeconds':10,'timeoutSeconds':5,'failureThreshold':6}
    c['startupProbe']={'exec':{'command':['pg_isready','-U','traderx','-d','traderx']},'periodSeconds':5,'timeoutSeconds':5,'failureThreshold':60}
    items=admission()+pod_admission()
    items += [{'apiVersion':'v1','kind':'PersistentVolumeClaim','metadata':{'name':PVC,'namespace':NS},'spec':{'accessModes':['ReadWriteOnce'],'storageClassName':'standard','resources':{'requests':{'storage':'2Gi'}}}},
      {'apiVersion':'v1','kind':'ServiceAccount','metadata':{'name':'lab-database','namespace':NS},'automountServiceAccountToken':False},
      {'apiVersion':'v1','kind':'ConfigMap','metadata':{'name':'lab-database-bootstrap','namespace':NS},'data':{'README':'Restore the verified lab backup; do not seed a new dataset.\n'}},d]
    return {'apiVersion':'v1','kind':'List','items':items}
