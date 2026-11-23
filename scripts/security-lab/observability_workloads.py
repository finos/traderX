"""Four stateful observability workload restrictions; explicit PVC data paths."""
import copy
import json
import workloads as business
import support_workloads as support
NS=business.NS
NAMES=['grafana','prometheus','loki','tempo']
POLICY='traderx-lab-observability'
PATHS={'grafana':['/var/lib/grafana'],'prometheus':['/prometheus'],'loki':['/tmp/loki','/loki'],'tempo':['/tmp/tempo','/var/tempo']}
HEALTH={'grafana':('/api/health',3000),'prometheus':('/prometheus/-/ready',9090),'loki':('/ready',3100),'tempo':('/ready',3200)}
CONFIGS={
 'grafana':[('grafana-datasources','observability-grafana-datasources','/etc/grafana/provisioning/datasources/datasources.yaml','datasources.yaml'),('grafana-dashboard-providers','observability-grafana-dashboard-providers','/etc/grafana/provisioning/dashboards/dashboards.yaml','dashboards.yaml'),('grafana-dashboards','observability-grafana-dashboards','/var/lib/grafana/dashboards',None)],
 'prometheus':[('prometheus-config','observability-prometheus-config','/etc/prometheus/prometheus.yml','prometheus.yml')],
 'loki':[('loki-config','observability-loki-config','/etc/loki/config.yaml','config.yaml')],
 'tempo':[('tempo-config','observability-tempo-config','/etc/tempo/config.yaml','config.yaml')]}


def mounts(name):
    volumes=[{'name':'lab-tmp','emptyDir':{'sizeLimit':'128Mi'}},{'name':'store','persistentVolumeClaim':{'claimName':'lab-'+name+'-data'}}]
    paths=[{'name':'lab-tmp','mountPath':'/tmp'}]+[{'name':'store','mountPath':p,'subPath':p.lstrip('/')} for p in PATHS[name]]
    for volume,cm,path,sub in CONFIGS[name]:
        volumes.append({'name':volume,'configMap':{'name':cm,'defaultMode':420}})
        m={'name':volume,'mountPath':path,'readOnly':True}
        if sub:m['subPath']=sub
        paths.append(m)
    return volumes,paths


def admission():
    docs=copy.deepcopy(business.admission());docs[0]['metadata']['name']=POLICY;docs[1]['metadata']['name']=POLICY;docs[1]['spec']['policyName']=POLICY
    spec=docs[0]['spec'];spec['matchConditions'][0]['expression']=f'object.metadata.namespace == "{NS}" && object.metadata.name in {json.dumps(NAMES)}'
    checks=spec['validations'][:7];p='object.spec.template.spec';c=p+'.containers[0]'
    checks.append({'expression':f'has({c}.resources) && has(dyn({c}.resources).requests) && has(dyn({c}.resources).limits) && dyn({c}.resources).requests == {{"cpu":"25m","memory":"64Mi"}} && dyn({c}.resources).limits == {{"cpu":"1","memory":(object.metadata.name in ["loki","tempo"] ? "768Mi" : "512Mi")}}','message':'WL: observability resource bounds required'})
    for name in NAMES:
        volumes,paths=mounts(name);terms=[f'{p}.volumes.size() == {len(volumes)}',f'{c}.volumeMounts.size() == {len(paths)}']
        for i,v in enumerate(volumes):
            a=f'{p}.volumes[{i}]';terms += [f'{a}.name == {json.dumps(v["name"])}']
            if 'emptyDir' in v:terms += [f'has({a}.emptyDir)',f'dyn({a}.emptyDir).sizeLimit == "128Mi"']
            elif 'persistentVolumeClaim' in v:terms += [f'has({a}.persistentVolumeClaim)',f'{a}.persistentVolumeClaim.claimName == "lab-{name}-data"']
            else:terms += [f'has({a}.configMap)',f'{a}.configMap.name == {json.dumps(v["configMap"]["name"])}']
        for i,m in enumerate(paths):
            a=f'{c}.volumeMounts[{i}]';terms += [f'{a}.name == {json.dumps(m["name"])}',f'{a}.mountPath == {json.dumps(m["mountPath"])}',f'!has({a}.subPathExpr)']
            if 'subPath' in m:terms += [f'has({a}.subPath)',f'{a}.subPath == {json.dumps(m["subPath"])}']
            else:terms += [f'!has({a}.subPath)']
            if m.get('readOnly'):terms += [f'has({a}.readOnly)',f'{a}.readOnly']
        checks.append({'expression':f'object.metadata.name != "{name}" || ('+' && '.join(terms)+')','message':'WL: reviewed data/config mounts for '+name})
    checks.append({'expression':'object.spec.strategy.type == "Recreate" && object.spec.replicas <= 1','message':'WL: single observability server required'})
    spec['validations']=checks;return docs


def pod_admission():
    docs=admission();docs[0]['spec']['validations']=[v for v in docs[0]['spec']['validations'] if v['message']!='WL: single observability server required']
    return support.pod_admission(docs,NAMES)


def render(reference):
    items=admission()+pod_admission()
    for name in NAMES:
        ds=[x for x in reference['items'] if x['kind']=='Deployment' and x['metadata']['name']==name]
        if len(ds)!=1:raise ValueError('Expected one '+name)
        d=copy.deepcopy(ds[0]);p=d['spec']['template']['spec'];c=p['containers'][0]
        expected=[{'name':v,'configMap':{'name':cm}} for v,cm,_,_ in CONFIGS[name]]
        if d['metadata']['namespace']!=NS or len(p['containers'])!=1 or p['volumes']!=expected or '@sha256:' not in c['image']:raise ValueError('Unreviewed observability layout: '+name)
        d['spec']['strategy']={'type':'Recreate'}
        p.update(serviceAccountName='lab-'+name,automountServiceAccountToken=False,securityContext={'runAsNonRoot':True,'runAsUser':10001,'runAsGroup':10001,'fsGroup':10001,'seccompProfile':{'type':'RuntimeDefault'}})
        p['volumes'],c['volumeMounts']=mounts(name)
        c['securityContext']={'allowPrivilegeEscalation':False,'readOnlyRootFilesystem':True,'capabilities':{'drop':['ALL']}}
        c['resources']={'requests':{'cpu':'25m','memory':'64Mi'},'limits':{'cpu':'1','memory':'768Mi' if name in ['loki','tempo'] else '512Mi'}}
        path,port=HEALTH[name]
        for key in ['readinessProbe','startupProbe']:
            c[key]={'httpGet':{'path':path,'port':port},'timeoutSeconds':5,'periodSeconds':5,'failureThreshold':60 if key=='startupProbe' else 3}
        if 'livenessProbe' in c:c['livenessProbe'].update(timeoutSeconds=5,failureThreshold=6)
        items += [{'apiVersion':'v1','kind':'PersistentVolumeClaim','metadata':{'name':'lab-'+name+'-data','namespace':NS},'spec':{'accessModes':['ReadWriteOnce'],'storageClassName':'standard','resources':{'requests':{'storage':'2Gi'}}}},
          {'apiVersion':'v1','kind':'ServiceAccount','metadata':{'name':'lab-'+name,'namespace':NS},'automountServiceAccountToken':False},d]
    return {'apiVersion':'v1','kind':'List','items':items}
