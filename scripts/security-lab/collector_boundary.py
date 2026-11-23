#!/usr/bin/env python3
"""Pinned collector exception in a separate namespace; full namespace Baseline next."""
import copy
import json
APP='traderx-security-lab'
INFRA='traderx-security-infra'
SA='lab-log-collector'
POLICY='traderx-lab-log-collector'
ROLE='traderx-lab-log-reader'
BASELINE={'pod-security.kubernetes.io/enforce':'baseline','pod-security.kubernetes.io/enforce-version':'v1.35'}


def pod_spec(image):
    return {'serviceAccountName':SA,'automountServiceAccountToken':False,
      'securityContext':{'runAsUser':0,'runAsGroup':0,'seccompProfile':{'type':'RuntimeDefault'}},
      'containers':[{'name':'promtail','image':image,'imagePullPolicy':'IfNotPresent','command':['/usr/local/bin/vector'],'args':['--config','/etc/vector/vector.toml'],
       'env':[{'name':'VECTOR_SELF_NODE_NAME','valueFrom':{'fieldRef':{'fieldPath':'spec.nodeName'}}},{'name':'VECTOR_NAMESPACE','valueFrom':{'fieldRef':{'fieldPath':'metadata.namespace'}}}],
       'securityContext':{'allowPrivilegeEscalation':False,'readOnlyRootFilesystem':True,'capabilities':{'drop':['ALL']}},
       'resources':{'requests':{'cpu':'10m','memory':'32Mi'},'limits':{'cpu':'1','memory':'256Mi'}},
       'volumeMounts':[{'name':'vector-config','mountPath':'/etc/vector/vector.toml','subPath':'vector.toml','readOnly':True},
        {'name':'varlogpods','mountPath':'/var/log/pods','readOnly':True},
        {'name':'run','mountPath':'/run/vector'},
        {'name':'api-access','mountPath':'/var/run/secrets/kubernetes.io/serviceaccount','readOnly':True}]}],
      'volumes':[{'name':'vector-config','configMap':{'name':'observability-promtail-config','defaultMode':420}},
       {'name':'varlogpods','hostPath':{'path':'/var/log/pods','type':'Directory'}},
       {'name':'run','emptyDir':{'sizeLimit':'64Mi'}},
       {'name':'api-access','projected':{'defaultMode':420,'sources':[
        {'serviceAccountToken':{'expirationSeconds':3600,'path':'token'}},
        {'configMap':{'name':'kube-root-ca.crt','items':[{'key':'ca.crt','path':'ca.crt'}]}},
        {'downwardAPI':{'items':[{'path':'namespace','fieldRef':{'apiVersion':'v1','fieldPath':'metadata.namespace'}}]}}]}}]}


def admission(image,kind):
    policy=POLICY+('-pods' if kind=='Pod' else '-daemonset')
    p='object.spec' if kind=='Pod' else 'object.spec.template.spec';c=p+'.containers[0]';s=p+'.securityContext'
    checks=[]
    def rule(expr,msg):checks.append({'expression':expr,'message':'CB: '+msg})
    rule(f'has({p}.serviceAccountName) && {p}.serviceAccountName == "{SA}" && has({p}.automountServiceAccountToken) && !{p}.automountServiceAccountToken','collector identity and explicit token only')
    rule(f'{p}.containers.size() == 1 && (!has({p}.initContainers) || {p}.initContainers.size() == 0) && (!has({p}.ephemeralContainers) || {p}.ephemeralContainers.size() == 0)','single reviewed collector; no debug containers')
    rule(f'{c}.name == "promtail" && {c}.image == {json.dumps(image)} && {c}.command == ["/usr/local/bin/vector"] && {c}.args == ["--config","/etc/vector/vector.toml"]','pinned collector executable only')
    rule(f'has({s}) && {s}.runAsUser == 0 && {s}.runAsGroup == 0 && {s}.seccompProfile.type == "RuntimeDefault" && !has({s}.sysctls) && !has({s}.supplementalGroups) && !has({s}.seLinuxOptions)','reviewed root identity and seccomp required')
    t=c+'.securityContext'
    rule(f'has({t}) && !{t}.allowPrivilegeEscalation && {t}.readOnlyRootFilesystem && {t}.capabilities.drop == ["ALL"] && (!has({t}.capabilities.add) || {t}.capabilities.add.size() == 0) && (!has({t}.privileged) || !{t}.privileged) && !has({t}.runAsUser) && !has({t}.runAsGroup) && !has({t}.seccompProfile) && !has({t}.procMount)','no privilege/capability/profile broadening')
    rule(' && '.join(f'(!has({p}.{f}) || !{p}.{f})' for f in ['hostNetwork','hostPID','hostIPC']),'host namespaces forbidden')
    rule(f'dyn({c}.resources).requests == {{"cpu":"10m","memory":"32Mi"}} && dyn({c}.resources).limits == {{"cpu":"1","memory":"256Mi"}}','reviewed resource bounds')
    rule(f'{c}.env.size() == 2 && {c}.env[0].name == "VECTOR_SELF_NODE_NAME" && {c}.env[0].valueFrom.fieldRef.fieldPath == "spec.nodeName" && {c}.env[1].name == "VECTOR_NAMESPACE" && {c}.env[1].valueFrom.fieldRef.fieldPath == "metadata.namespace"','reviewed environment only')
    rule(f'{p}.volumes.size() == 4 && {p}.volumes[0].name == "vector-config" && {p}.volumes[0].configMap.name == "observability-promtail-config" && {p}.volumes[1].name == "varlogpods" && {p}.volumes[1].hostPath.path == "/var/log/pods" && {p}.volumes[1].hostPath.type == "Directory" && {p}.volumes[2].name == "run" && dyn({p}.volumes[2].emptyDir).sizeLimit == "64Mi" && {p}.volumes[3].name == "api-access"','exact config, read-only host-log source, state and token volumes')
    q=p+'.volumes[3].projected.sources'
    rule(f'{q}.size() == 3 && {q}[0].serviceAccountToken.path == "token" && {q}[0].serviceAccountToken.expirationSeconds == 3600 && !has({q}[0].serviceAccountToken.audience) && {q}[1].configMap.name == "kube-root-ca.crt" && {q}[1].configMap.items.size() == 1 && {q}[1].configMap.items[0].key == "ca.crt" && {q}[1].configMap.items[0].path == "ca.crt" && {q}[2].downwardAPI.items.size() == 1 && {q}[2].downwardAPI.items[0].path == "namespace" && {q}[2].downwardAPI.items[0].fieldRef.fieldPath == "metadata.namespace"','bounded API token projection only')
    terms=[f'{c}.volumeMounts.size() == 4']
    for i,m in enumerate(pod_spec(image)['containers'][0]['volumeMounts']):
        a=f'{c}.volumeMounts[{i}]';terms += [f'{a}.name == {json.dumps(m["name"])}',f'{a}.mountPath == {json.dumps(m["mountPath"])}',f'!has({a}.subPathExpr)',f'!has({a}.mountPropagation)']
        terms += [f'{a}.subPath == "vector.toml"'] if i==0 else [f'!has({a}.subPath)']
        if m.get('readOnly'):terms += [f'has({a}.readOnly)',f'{a}.readOnly']
    rule(' && '.join(terms),'exact mount paths with host logs read-only')
    if kind=='DaemonSet':rule('object.metadata.name == "promtail"','only the collector DaemonSet')
    rule_spec={'apiGroups':['' if kind=='Pod' else 'apps'],'apiVersions':['v1'],'operations':['CREATE','UPDATE'],'resources':['pods','pods/ephemeralcontainers'] if kind=='Pod' else ['daemonsets']}
    return [{'apiVersion':'admissionregistration.k8s.io/v1','kind':'ValidatingAdmissionPolicy','metadata':{'name':policy},'spec':{'failurePolicy':'Fail','matchConstraints':{'resourceRules':[rule_spec]},'matchConditions':[{'name':'infra-namespace','expression':f'object.metadata.namespace == "{INFRA}"'}],'validations':checks}},
      {'apiVersion':'admissionregistration.k8s.io/v1','kind':'ValidatingAdmissionPolicyBinding','metadata':{'name':policy},'spec':{'policyName':policy,'validationActions':['Deny']}}]


def render(reference):
    d=copy.deepcopy(next(x for x in reference['items'] if x['kind']=='DaemonSet' and x['metadata']['name']=='promtail'))
    image=d['spec']['template']['spec']['containers'][0]['image']
    if '@sha256:' not in image:raise ValueError('Collector must be pinned')
    cm=copy.deepcopy(next(x for x in reference['items'] if x['kind']=='ConfigMap' and x['metadata']['name']=='observability-promtail-config'))
    cm['metadata']['namespace']=INFRA
    config=cm['data']['vector.toml']
    if 'metadata.namespace='+APP not in config or 'http://loki:3100' not in config:raise ValueError('Unreviewed collector configuration')
    cm['data']['vector.toml']=config.replace('http://loki:3100','http://loki.'+APP+'.svc.cluster.local:3100')
    d['metadata']['namespace']=INFRA;d['spec']['template']['spec']=pod_spec(image)
    items=admission(image,'Pod')+admission(image,'DaemonSet')
    items += [{'apiVersion':'v1','kind':'Namespace','metadata':{'name':INFRA,'labels':{'pod-security.kubernetes.io/enforce':'privileged','pod-security.kubernetes.io/enforce-version':'v1.35'}}},
      {'apiVersion':'v1','kind':'ServiceAccount','metadata':{'name':SA,'namespace':INFRA},'automountServiceAccountToken':False},
      {'apiVersion':'rbac.authorization.k8s.io/v1','kind':'ClusterRole','metadata':{'name':ROLE},'rules':[{'apiGroups':[''],'resources':['pods','nodes','namespaces'],'verbs':['get','list','watch']}]},
      {'apiVersion':'rbac.authorization.k8s.io/v1','kind':'ClusterRoleBinding','metadata':{'name':ROLE},'subjects':[{'kind':'ServiceAccount','name':SA,'namespace':INFRA}],'roleRef':{'apiGroup':'rbac.authorization.k8s.io','kind':'ClusterRole','name':ROLE}},cm,d]
    return {'apiVersion':'v1','kind':'List','items':items}
