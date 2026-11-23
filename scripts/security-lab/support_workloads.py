#!/usr/bin/env python3
"""Render six stateless supporting workloads and scoped direct-Pod admission."""
import copy
import json
import workloads as business
NS=business.NS
NAMES=['nats-broker','blackbox-exporter','otel-collector','web-front-end-angular','api-explorer','edge-proxy']
NGINX={'edge-proxy','web-front-end-angular','api-explorer'}
POLICY='traderx-lab-support-workloads'
# Reviewed existing volume/configmap/file/subPath layout from the pinned reference.
CONFIGS={
 'edge-proxy':('edge-proxy-config','edge-proxy-config','/etc/nginx/conf.d/default.conf','default.conf'),
 'nats-broker':('nats-config','nats-config','/etc/nats/nats.conf','nats.conf'),
 'blackbox-exporter':('blackbox-config','observability-blackbox-config','/etc/blackbox_exporter/config.yml','blackbox.yml'),
 'otel-collector':('otel-config','observability-otel-collector-config','/etc/otelcol-contrib/config.yaml','config.yaml')}
HEALTH={'nats-broker':('/healthz',8222),'blackbox-exporter':('/-/healthy',9115),'otel-collector':('/',13133),
 'web-front-end-angular':('/',18093),'api-explorer':('/api/docs/',8080),'edge-proxy':('/health',8080)}
API_CONFIG='server { listen 8080; server_name localhost; location / { root /usr/share/nginx/html; index index.html index.htm; } }\n'


def mounts(name):
    volumes=[{'name':'lab-tmp','emptyDir':{'sizeLimit':'128Mi'}}]
    paths=[{'name':'lab-tmp','mountPath':'/tmp'}]
    if name in NGINX:
        for volume,path,size in [('lab-run','/run','16Mi'),('lab-cache','/var/cache/nginx','32Mi')]:
            volumes.append({'name':volume,'emptyDir':{'sizeLimit':size}});paths.append({'name':volume,'mountPath':path})
    config=CONFIGS.get(name)
    if name=='api-explorer': config=('lab-api-config','lab-api-explorer-config','/etc/nginx/conf.d/default.conf','default.conf')
    if config:
        volume,cm,path,sub=config
        volumes.append({'name':volume,'configMap':{'name':cm,'defaultMode':420}})
        paths.append({'name':volume,'mountPath':path,'subPath':sub,'readOnly':True})
    return volumes,paths


def admission():
    docs=copy.deepcopy(business.admission());policy=docs[0];policy['metadata']['name']=POLICY
    docs[1]['metadata']['name']=POLICY;docs[1]['spec']['policyName']=POLICY
    policy['spec']['matchConditions'][0]['expression']=f'object.metadata.namespace == "{NS}" && object.metadata.name in {json.dumps(NAMES)}'
    checks=policy['spec']['validations'][:7]
    p='object.spec.template.spec';c=p+'.containers[0]'
    # Do not permit quantities outside the reviewed bounded resource allocation.
    checks.append({'expression':f'has({c}.resources) && has(dyn({c}.resources).requests) && has(dyn({c}.resources).limits) && dyn({c}.resources).requests == {{"cpu":"10m","memory":"32Mi"}} && dyn({c}.resources).limits == {{"cpu":"1","memory":(object.metadata.name in {json.dumps(sorted(NGINX))} ? "256Mi" : "512Mi")}}','message':'WL: support resource bounds required'})
    for name in NAMES:
        volumes,paths=mounts(name)
        terms=[f'has({p}.volumes)',f'{p}.volumes.size() == {len(volumes)}',f'has({c}.volumeMounts)',f'{c}.volumeMounts.size() == {len(paths)}']
        for i,v in enumerate(volumes):
            a=f'{p}.volumes[{i}]';terms.append(f'{a}.name == {json.dumps(v["name"])}')
            if 'emptyDir' in v:
                terms.extend([f'has({a}.emptyDir)',f'has(dyn({a}.emptyDir).sizeLimit)',f'dyn({a}.emptyDir).sizeLimit == {json.dumps(v["emptyDir"]["sizeLimit"])}'])
            else: terms.extend([f'has({a}.configMap)',f'{a}.configMap.name == {json.dumps(v["configMap"]["name"])}'])
        for i,m in enumerate(paths):
            a=f'{c}.volumeMounts[{i}]'
            terms.extend([f'{a}.name == {json.dumps(m["name"])}',f'{a}.mountPath == {json.dumps(m["mountPath"])}',f'!has({a}.subPathExpr)'])
            if 'subPath' in m: terms.extend([f'has({a}.subPath)',f'{a}.subPath == {json.dumps(m["subPath"])}',f'has({a}.readOnly)',f'{a}.readOnly'])
            else: terms.append(f'!has({a}.subPath)')
        checks.append({'expression':f'object.metadata.name != "{name}" || ('+' && '.join(terms)+')','message':'WL: exact reviewed mounts required for '+name})
    policy['spec']['validations']=checks
    return docs


def pod_admission(deployment_docs,names):
    docs=copy.deepcopy(deployment_docs)
    name=docs[0]['metadata']['name']+'-pods'
    docs[0]['metadata']['name']=name;docs[1]['metadata']['name']=name;docs[1]['spec']['policyName']=name
    spec=docs[0]['spec']
    spec['matchConstraints']['resourceRules']=[{'apiGroups':[''],'apiVersions':['v1'],'operations':['CREATE','UPDATE'],'resources':['pods','pods/ephemeralcontainers']}]
    spec['matchConditions']=[{'name':'protected-label-or-identity','expression':f'object.metadata.namespace == "{NS}" && ((has(object.metadata.labels) && "app" in object.metadata.labels && object.metadata.labels["app"] in {json.dumps(names)}) || (has(object.spec.serviceAccountName) && object.spec.serviceAccountName in {json.dumps(["lab-"+n for n in names])}))'}]
    for v in spec['validations']:
        v['expression']=v['expression'].replace('object.spec.template.spec','object.spec').replace('object.metadata.name','object.metadata.labels["app"]')
    spec['validations'].insert(0,{'expression':f'has(object.metadata.labels) && "app" in object.metadata.labels && object.metadata.labels["app"] in {json.dumps(names)}','message':'WL: protected service identity requires its app label'})
    return docs


def render(reference):
    result=admission()
    result+=pod_admission(business.admission(),business.NAMES)+pod_admission(admission(),NAMES)
    result.append({'apiVersion':'v1','kind':'ConfigMap','metadata':{'name':'lab-api-explorer-config','namespace':NS},'data':{'default.conf':API_CONFIG}})
    for name in NAMES:
        candidates=[d for d in reference['items'] if d['kind']=='Deployment' and d['metadata']['name']==name]
        if len(candidates)!=1: raise ValueError('Expected one '+name)
        d=copy.deepcopy(candidates[0]);p=d['spec']['template']['spec']
        if d['metadata']['namespace']!=NS or len(p['containers'])!=1 or p.get('initContainers'): raise ValueError('Unreviewed workload '+name)
        c=p['containers'][0]
        if c['name']!=name or '@sha256:' not in c['image']: raise ValueError('Unpinned container '+name)
        old=CONFIGS.get(name)
        if old:
            volume,cm,path,sub=old
            expected=[{'name':volume,'configMap':{'name':cm}}]
            if p.get('volumes')!=expected or c.get('volumeMounts')!=[{'name':volume,'mountPath':path,'subPath':sub}]: raise ValueError('Unreviewed config '+name)
        elif p.get('volumes') or c.get('volumeMounts'): raise ValueError('Unreviewed mounts '+name)
        d['spec']['strategy']={'type':'RollingUpdate','rollingUpdate':{'maxSurge':0,'maxUnavailable':1}}
        p.update(serviceAccountName='lab-'+name,automountServiceAccountToken=False,securityContext={'runAsNonRoot':True,'runAsUser':10001,'runAsGroup':10001,'fsGroup':10001,'seccompProfile':{'type':'RuntimeDefault'}})
        p['volumes'],c['volumeMounts']=mounts(name)
        c['securityContext']={'allowPrivilegeEscalation':False,'readOnlyRootFilesystem':True,'capabilities':{'drop':['ALL']}}
        c['resources']={'requests':{'cpu':'10m','memory':'32Mi'},'limits':{'cpu':'1','memory':'256Mi' if name in NGINX else '512Mi'}}
        path,port=HEALTH[name]
        c['readinessProbe']={'httpGet':{'path':path,'port':port},'periodSeconds':5,'timeoutSeconds':5,'failureThreshold':3}
        if name in NGINX: c.update(command=['nginx'],args=['-g','daemon off;'])
        if name=='api-explorer': c['ports']=[{'containerPort':8080,'name':'http'}]
        result.extend([{'apiVersion':'v1','kind':'ServiceAccount','metadata':{'name':'lab-'+name,'namespace':NS},'automountServiceAccountToken':False},d])
    matches=[d for d in reference['items'] if d['kind']=='Service' and d['metadata']['name']=='api-explorer']
    if len(matches)!=1: raise ValueError('Expected API explorer Service')
    svc=copy.deepcopy(matches[0])
    if svc['metadata']['namespace']!=NS or len(svc['spec']['ports'])!=1 or svc['spec']['ports'][0]['targetPort']!=80: raise ValueError('Unreviewed API docs service')
    svc['spec']['ports'][0]['targetPort']=8080;result.append(svc)
    return {'apiVersion':'v1','kind':'List','items':result}
