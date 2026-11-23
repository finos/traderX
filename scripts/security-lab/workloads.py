#!/usr/bin/env python3
"""Render the reviewed business-service restrictions, without touching a cluster."""
import argparse
import copy
import json
from pathlib import Path

NS = 'traderx-security-lab'
NAMES = ['account-service','position-service','trade-service','trade-processor','order-matcher','people-service','reference-data','price-publisher']
JAVA = set(NAMES[:5])
POLICY = 'traderx-lab-business-workloads'
HEALTH = {'account-service':('/actuator/health',18088), 'position-service':('/health/ready',18090), 'trade-service':('/actuator/health',18092), 'trade-processor':('/actuator/health',18091), 'order-matcher':('/health',18110), 'people-service':('/People/ValidatePerson?LogonId=user01',18089), 'reference-data':('/health',18085), 'price-publisher':('/health',18100)}


def admission():
    p='object.spec.template.spec'
    c=p+'.containers[0]'
    validations=[]
    def rule(expression,message):
        expression = expression.replace(c+'.resources.', 'dyn('+c+'.resources).').replace(p+'.volumes[0].emptyDir.', 'dyn('+p+'.volumes[0].emptyDir).')
        validations.append({'expression':expression,'message':'WL: '+message})
    rule(f'has({p}.serviceAccountName) && {p}.serviceAccountName == "lab-" + object.metadata.name && has({p}.automountServiceAccountToken) && !{p}.automountServiceAccountToken','dedicated identity without token required')
    s=p+'.securityContext'
    rule(f'has({p}.securityContext) && has({s}.runAsNonRoot) && {s}.runAsNonRoot && has({s}.runAsUser) && {s}.runAsUser == 10001 && has({s}.runAsGroup) && {s}.runAsGroup == 10001 && has({s}.seccompProfile) && {s}.seccompProfile.type == "RuntimeDefault"','non-root identity and RuntimeDefault required')
    rule(f'has({s}.fsGroup) && {s}.fsGroup == 10001 && !has({s}.supplementalGroups) && !has({s}.sysctls) && !has({s}.seLinuxOptions) && !has({s}.appArmorProfile)', 'only reviewed pod groups and profiles allowed')
    rule(f'{p}.containers.size() == 1 && (!has({p}.initContainers) || {p}.initContainers.size() == 0) && (!has({p}.ephemeralContainers) || {p}.ephemeralContainers.size() == 0)','reviewed single container only')
    s=c+'.securityContext'
    rule(f'has({c}.securityContext) && has({s}.allowPrivilegeEscalation) && !{s}.allowPrivilegeEscalation && has({s}.readOnlyRootFilesystem) && {s}.readOnlyRootFilesystem && (!has({s}.privileged) || !{s}.privileged) && has({s}.capabilities) && {s}.capabilities.drop == ["ALL"] && (!has({s}.capabilities.add) || {s}.capabilities.add.size() == 0)','read-only root, no escalation or capabilities required')
    rule(f'!has({s}.runAsUser) && !has({s}.runAsGroup) && !has({s}.runAsNonRoot) && !has({s}.seccompProfile) && !has({s}.procMount) && !has({s}.seLinuxOptions) && !has({s}.appArmorProfile)','container cannot override reviewed pod identity/profile')
    rule(' && '.join(f'(!has({p}.{field}) || !{p}.{field})' for field in ['hostNetwork','hostPID','hostIPC']),'host namespaces forbidden')
    rule(f'has({p}.volumes) && {p}.volumes.size() == 1 && {p}.volumes[0].name == "lab-tmp" && has({p}.volumes[0].emptyDir) && has({p}.volumes[0].emptyDir.sizeLimit) && {p}.volumes[0].emptyDir.sizeLimit == "128Mi"','only bounded tmp volume allowed')
    rule(f'has({c}.volumeMounts) && {c}.volumeMounts.size() == 1 && {c}.volumeMounts[0].name == "lab-tmp" && {c}.volumeMounts[0].mountPath == "/tmp" && !has({c}.volumeMounts[0].subPath) && !has({c}.volumeMounts[0].subPathExpr)','only reviewed /tmp mount allowed')
    rule(f'has({c}.resources) && has({c}.resources.requests) && has({c}.resources.limits) && "cpu" in {c}.resources.requests && "memory" in {c}.resources.requests && "cpu" in {c}.resources.limits && "memory" in {c}.resources.limits && {c}.resources.requests.cpu == "25m" && {c}.resources.requests.memory == "64Mi" && {c}.resources.limits.cpu == "2" && {c}.resources.limits.memory == (object.metadata.name in {json.dumps(sorted(JAVA))} ? "768Mi" : "512Mi")','reviewed CPU/memory bounds required')
    return [dict(apiVersion='admissionregistration.k8s.io/v1',kind='ValidatingAdmissionPolicy',metadata={'name':POLICY},spec={
        'failurePolicy':'Fail','matchConstraints':{'resourceRules':[{'apiGroups':['apps'],'apiVersions':['v1'],'operations':['CREATE','UPDATE'],'resources':['deployments']}]},
        'matchConditions':[{'name':'reviewed-deployments','expression':f'object.metadata.namespace == "{NS}" && object.metadata.name in {json.dumps(NAMES)}'}],
        'validations':validations}),dict(apiVersion='admissionregistration.k8s.io/v1',kind='ValidatingAdmissionPolicyBinding',metadata={'name':POLICY},spec={'policyName':POLICY,'validationActions':['Deny']})]


def render(reference):
    result=[]
    for name in NAMES:
        matches=[d for d in reference['items'] if d['kind']=='Deployment' and d['metadata']['name']==name]
        if len(matches)!=1: raise ValueError('Expected exactly one '+name)
        d=copy.deepcopy(matches[0]); pod=d['spec']['template']['spec']
        if d['metadata']['namespace']!=NS or len(pod['containers'])!=1 or any(pod.get(k) for k in ['volumes','initContainers','ephemeralContainers']):
            raise ValueError('Unreviewed workload layout: '+name)
        d['spec']['strategy']={'type':'RollingUpdate','rollingUpdate':{'maxSurge':0,'maxUnavailable':1}}
        container=pod['containers'][0]
        if container.get('volumeMounts') or container['name']!=name or '@sha256:' not in container['image']:
            raise ValueError('Unreviewed container: '+name)
        pod.update(serviceAccountName='lab-'+name,automountServiceAccountToken=False,
            securityContext={'runAsNonRoot':True,'runAsUser':10001,'runAsGroup':10001,'fsGroup':10001,'seccompProfile':{'type':'RuntimeDefault'}},
            volumes=[{'name':'lab-tmp','emptyDir':{'sizeLimit':'128Mi'}}])
        path,port=HEALTH[name]
        container['readinessProbe']={'httpGet':{'path':path,'port':port},'periodSeconds':5,'timeoutSeconds':5,'failureThreshold':3}
        container.update(securityContext={'allowPrivilegeEscalation':False,'readOnlyRootFilesystem':True,'capabilities':{'drop':['ALL']}},
            volumeMounts=[{'name':'lab-tmp','mountPath':'/tmp'}],
            resources={'requests':{'cpu':'25m','memory':'64Mi'},'limits':{'cpu':'2','memory':'768Mi' if name in JAVA else '512Mi'}})
        result.append({'apiVersion':'v1','kind':'ServiceAccount','metadata':{'name':'lab-'+name,'namespace':NS},'automountServiceAccountToken':False})
        result.append(d)
    return {'apiVersion':'v1','kind':'List','items':admission()+result}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    args.output.write_text(json.dumps(render(json.loads(args.reference.read_text())),indent=2)+'\n')
