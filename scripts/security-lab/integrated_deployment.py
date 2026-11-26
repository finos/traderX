"""Compile verified OCI application artifacts into a staged, fail-closed core bundle."""
import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[2]
STATE=ROOT/'specs/019-traderx-security-lab'
ROLES={'account-service':18088,'position-service':18090,
       'trade-processor':18091,'order-matcher':18110,'people-service':18089,
       'browser-session':18447,
       'event-publisher':None,'event-consumer':None}
WORKERS={'event-publisher','event-consumer','browser-session'}
MATERIALIZED_ROLES=WORKERS|{'position-service'}
DEPS={'database':(5432,'tls'),'nats-broker':(4222,'tls'),
      'identity':(8443,'https'),'reference-data':(18085,'https'),'price-publisher':(18100,'https')}
EDGES={
 'browser-session':['account-service','position-service','order-matcher','reference-data','price-publisher','identity','nats-broker'],
 'account-service':['database'], 'position-service':['database'],
 'trade-processor':['database'],
 'order-matcher':['database','trade-processor','identity','nats-broker'],
 'event-publisher':['database','nats-broker'], 'event-consumer':['database','nats-broker']}
MIGRATIONS=['execution-reservations.sql','execution-settlement.sql',
            'execution-cancellation.sql','execution-events.sql','execution-consumer.sql']
DIGEST=re.compile(r'sha256:([0-9a-f]{64})')
NAME=re.compile(r'[a-z][a-z0-9-]{0,61}[a-z0-9]|[a-z]')


def encoded(value):return (json.dumps(value,sort_keys=True,indent=2)+'\n').encode()
def sha(value):return hashlib.sha256(value).hexdigest()


def source_manifest():
    paths=set((ROOT/'scripts/security-lab').glob('*.py'))
    paths={p for p in paths if not p.name.startswith('test_')}
    for directory in (STATE/'generation',STATE/'system/sql',ROOT/'specs/012-platform-convergence-c3/security-lab/generation'):
        paths.update(p for p in directory.rglob('*') if p.is_file())
    paths.add(ROOT/'specs/012-platform-convergence-c3/security-lab/baseline.lock.json')
    paths.add(STATE/'system/runtime-images.lock.json')
    paths.add(STATE/'system/java-runtime-images.lock.json')
    values={str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in sorted(paths)}
    return {'files':values,'sha256':sha(encoded(values))}


def read_json(path,limit=4*1024*1024):
    def pairs(items):
        result={}
        for key,value in items:
            if key in result:raise ValueError('Duplicate JSON field')
            result[key]=value
        return result
    with Path(path).open('rb') as stream:raw=stream.read(limit+1)
    if len(raw)>limit:raise ValueError('Artifact metadata exceeds limit')
    return json.loads(raw,object_pairs_hook=pairs)


def blob(layout,descriptor,metadata=True):
    match=DIGEST.fullmatch(descriptor.get('digest',''))
    if not match or type(descriptor.get('size')) is not int or descriptor['size']<0:
        raise ValueError('Invalid OCI descriptor')
    path=layout/'blobs/sha256'/match[1]
    if path.is_symlink() or not path.resolve().is_relative_to(layout.resolve()) or not path.is_file() or path.stat().st_size!=descriptor['size']:
        raise ValueError('Missing or changed OCI blob')
    digest=hashlib.sha256()
    with path.open('rb') as stream:
        for part in iter(lambda:stream.read(1024*1024),b''):digest.update(part)
    if digest.hexdigest()!=match[1]:raise ValueError('OCI digest mismatch')
    return read_json(path) if metadata else None


def image(role,value,source,revision,platform):
    if set(value)!={'image','oci_layout','secret','keys'}:
        raise ValueError('Incomplete image/configuration reference')
    ref=value['image']
    if not isinstance(ref,str) or not re.fullmatch(r'[a-z0-9][a-z0-9./:_-]+@sha256:[0-9a-f]{64}',ref):
        raise ValueError('Pinned image reference required')
    layout=Path(value['oci_layout'])
    if not layout.is_absolute() or layout.is_symlink():raise ValueError('Absolute OCI layout required')
    if read_json(layout/'oci-layout')!={'imageLayoutVersion':'1.0.0'}:raise ValueError('OCI layout version changed')
    index=read_json(layout/'index.json')
    candidates=[d for d in index.get('manifests',[]) if d.get('digest')==ref.split('@')[1]]
    if len(candidates)!=1:raise ValueError('Pinned image not uniquely present in OCI index')
    manifest=blob(layout,candidates[0])
    if manifest.get('schemaVersion')!=2 or manifest.get('mediaType')!='application/vnd.oci.image.manifest.v1+json':
        raise ValueError('Single-platform OCI manifest required')
    if manifest.get('config',{}).get('mediaType')!='application/vnd.oci.image.config.v1+json':
        raise ValueError('OCI image configuration descriptor required')
    config=blob(layout,manifest['config'])
    layers=manifest.get('layers',[])
    for layer in layers:
        if layer.get('mediaType') not in ('application/vnd.oci.image.layer.v1.tar','application/vnd.oci.image.layer.v1.tar+gzip','application/vnd.oci.image.layer.v1.tar+zstd'):
            raise ValueError('OCI image layer descriptor required')
        blob(layout,layer,False)
    if not manifest.get('layers'):raise ValueError('Image contains no layers')
    rootfs=config.get('rootfs',{})
    if rootfs.get('type')!='layers' or len(rootfs.get('diff_ids',[]))!=len(layers) or any(not DIGEST.fullmatch(d) for d in rootfs['diff_ids']):
        raise ValueError('OCI root filesystem inventory required')
    if config.get('os')!='linux' or config.get('architecture')!=platform.split('/')[1]:
        raise ValueError('Image platform mismatch')
    runtime=config.get('config',{});labels=runtime.get('Labels',{})
    expected={'org.opencontainers.image.revision':revision,
        'traderx.security-lab.role':role,'traderx.security-lab.source-manifest':source['sha256'],
        'traderx.security-lab.config-interface':'private-config-v1'}
    if any(labels.get(k)!=v for k,v in expected.items()):raise ValueError('Image source or interface contract mismatch')
    if runtime.get('User')!='10001:10001':raise ValueError('Reviewed image UID required')
    if any(re.search(r'(^|_)(PASSWORD|DBPASS|TOKEN|SECRET|API_KEY)=',v,re.I) for v in runtime.get('Env',[])):
        raise ValueError('Image contains credential environment values')
    # OCI exporters may encode unset/empty command arrays as null. Treat only
    # absent/null as empty; strings and other values must never become argv.
    parts=[]
    for field in ('Entrypoint','Cmd'):
        value_part=runtime.get(field)
        if value_part is None:value_part=[]
        if not isinstance(value_part,list):raise ValueError('Image argv fields must be arrays or null')
        parts.extend(value_part)
    argv=parts
    if (not argv or len(argv)>64 or not all(isinstance(a,str) and 0<len(a)<=512 and not re.search(r'[\x00-\x1f]',a) for a in argv)
            or not Path(argv[0]).is_absolute() or Path(argv[0]).name in ('sh','bash','dash','zsh','env')):
        raise ValueError('Explicit non-shell image argv required')
    if ROLES[role] is not None:
        if labels.get('traderx.security-lab.bind-address')!='0.0.0.0' or labels.get('traderx.security-lab.transport')!='https':
            raise ValueError('Reachable HTTPS listener declaration required')
        if labels.get('traderx.security-lab.port')!=str(ROLES[role]):raise ValueError('Listener port mismatch')
    keys=value['keys']
    if (not isinstance(keys,list) or keys!=sorted(set(keys)) or not 1<=len(keys)<=16
            or 'config.json' not in keys or any(not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]{0,63}',k) for k in keys)
            or not isinstance(value['secret'],str) or not NAME.fullmatch(value['secret'])):
        raise ValueError('Explicit private Secret key inventory required')
    if role in MATERIALIZED_ROLES:
        prefix=[argv[0],'/opt/traderx/private_materializer.py','--source','/run/projected','--target','/run/private/config']
        prefix += [part for key in keys for part in ('--key',key)]
        prefix += ['--']
        if argv[:len(prefix)]!=prefix or len(argv)<=len(prefix) or not Path(argv[len(prefix)]).is_absolute():
            raise ValueError('Private-file runtime requires reviewed materializer argv')
    if role=='position-service':
        from java_runtime import KEYS
        expected=['/usr/local/bin/python','/opt/traderx/private_materializer.py','--source','/run/projected','--target','/run/private/config']
        expected += [part for key in KEYS for part in ('--key',key)]
        expected += ['--','/usr/local/bin/python','/opt/traderx/java_runtime.py','--role','position-service','--config','/run/private/config/config.json']
        if keys!=KEYS or argv!=expected:raise ValueError('Protected position adapter contract required')
    return argv


def meta(name,namespace):return {'name':name,'namespace':namespace,'labels':{'traderx.security-lab.profile':'integrated-core'}}
def peer(name,namespace=None):
    result={'podSelector':{'matchLabels':{'app':name}}}
    if namespace:result['namespaceSelector']={'matchLabels':{'kubernetes.io/metadata.name':namespace}}
    return result


def network(namespace,gateway):
    items=[{'apiVersion':'networking.k8s.io/v1','kind':'NetworkPolicy','metadata':meta('integrated-default-deny',namespace),
        'spec':{'podSelector':{},'policyTypes':['Ingress','Egress'],'ingress':[],'egress':[]}}]
    ports={**ROLES,**{name:value[0] for name,value in DEPS.items()}}
    ingress={name:[] for name in ports}
    for role in ('browser-session',):
        ingress[role].append({'from':[peer(gateway['name'],gateway['namespace'])],
            'ports':[{'protocol':'TCP','port':ports[role]}]})
    for source,targets in EDGES.items():
        for target in targets:ingress[target].append({'from':[peer(source)],'ports':[{'protocol':'TCP','port':ports[target]}]})
    for name in sorted(ports):
        egress=[{'to':[peer(target)],'ports':[{'protocol':'TCP','port':ports[target]}]} for target in EDGES.get(name,[])]
        if name in ROLES:
            egress.append({'to':[{'namespaceSelector':{'matchLabels':{'kubernetes.io/metadata.name':'kube-system'}},
                'podSelector':{'matchLabels':{'k8s-app':'kube-dns'}}}],
                'ports':[{'protocol':'UDP','port':53},{'protocol':'TCP','port':53}]})
        items.append({'apiVersion':'networking.k8s.io/v1','kind':'NetworkPolicy','metadata':meta('integrated-'+name,namespace),
            'spec':{'podSelector':{'matchLabels':{'app':name}},'policyTypes':['Ingress','Egress'],
                    'ingress':ingress[name],'egress':egress}})
    return items


def workload(name,entry,argv,namespace):
    volumes=[{'name':'tmp','emptyDir':{'sizeLimit':'64Mi'}},
             {'name':'runtime','secret':{'secretName':entry['secret'],'optional':False,'defaultMode':0o440,
                'items':[{'key':key,'path':key} for key in entry['keys']]}}]
    mounts=[{'name':'tmp','mountPath':'/tmp'},{'name':'runtime','mountPath':'/run/projected','readOnly':True}]
    if name in MATERIALIZED_ROLES:
        volumes.append({'name':'private','emptyDir':{'sizeLimit':'16Mi'}})
        mounts.append({'name':'private','mountPath':'/run/private'})
    container={'name':name,'image':entry['image'],'imagePullPolicy':'IfNotPresent','command':argv,
        'securityContext':{'allowPrivilegeEscalation':False,'readOnlyRootFilesystem':True,'capabilities':{'drop':['ALL']}},
        'resources':{'requests':{'cpu':'100m','memory':'128Mi'},'limits':{'cpu':'1','memory':'768Mi' if name in ('account-service','position-service','trade-processor','order-matcher') else '256Mi'}},
        'volumeMounts':mounts}
    if ROLES[name] is not None:
        container['ports']=[{'name':'https','containerPort':ROLES[name]}]
        container['readinessProbe']={'tcpSocket':{'port':'https'},'periodSeconds':5,'timeoutSeconds':2}
    pod={'serviceAccountName':'lab-'+name,'automountServiceAccountToken':False,
         'securityContext':{'runAsNonRoot':True,'runAsUser':10001,'runAsGroup':10001,'fsGroup':10001,
                            'seccompProfile':{'type':'RuntimeDefault'}},'containers':[container],'volumes':volumes}
    items=[{'apiVersion':'v1','kind':'ServiceAccount','metadata':meta('lab-'+name,namespace),'automountServiceAccountToken':False},
        {'apiVersion':'apps/v1','kind':'Deployment','metadata':meta(name,namespace),
         'spec':{'replicas':0,'strategy':{'type':'Recreate'},'selector':{'matchLabels':{'app':name}},
                 'template':{'metadata':{'labels':{'app':name}},'spec':pod}}}]
    if ROLES[name] is not None:
        items.append({'apiVersion':'v1','kind':'Service','metadata':meta(name,namespace),
            'spec':{'type':'ClusterIP','selector':{'app':name},'ports':[{'name':'https','port':ROLES[name],'targetPort':'https'}]}})
    return items


def admission(namespace,entries,commands):
    result=[]
    for kind in ('pods','deployments'):
        pod='object.spec' if kind=='pods' else 'object.spec.template.spec'
        labels='object.metadata.labels' if kind=='pods' else 'object.spec.template.metadata.labels'
        c=pod+'.containers[0]'
        pairs=[]
        for role,entry in sorted(entries.items()):
            keycheck=' && '.join(f'v.secret.items.exists(i, i.key == {json.dumps(key)} && i.path == {json.dumps(key)})' for key in entry['keys'])
            count=3 if role in MATERIALIZED_ROLES else 2
            memory='768Mi' if role in ('account-service','position-service','trade-processor','order-matcher') else '256Mi'
            pairs.append(f'({labels}["app"] == {json.dumps(role)} && {c}.image == {json.dumps(entry["image"])}'
                f' && {pod}.serviceAccountName == {json.dumps("lab-"+role)} && has({c}.command) && {c}.command == {json.dumps(commands[role])}'
                f' && {pod}.volumes.size() == {count} && {c}.volumeMounts.size() == {count}'
                f' && dyn({c}.resources).requests.cpu == "100m" && dyn({c}.resources).requests.memory == "128Mi"'
                f' && dyn({c}.resources).limits.cpu == "1" && dyn({c}.resources).limits.memory == {json.dumps(memory)}'
                f' && {pod}.volumes.exists(v, v.name == "runtime" && has(v.secret) && v.secret.secretName == {json.dumps(entry["secret"])}'
                f' && has(v.secret.optional) && !v.secret.optional && v.secret.defaultMode == 288'
                f' && has(v.secret.items) && v.secret.items.size() == {len(entry["keys"])} && {keycheck}))')
        expressions=[f'has({labels}) && "app" in {labels} && has({pod}.serviceAccountName) && {pod}.containers.size() == 1 && ('+' || '.join(pairs)+')',
            f'has({pod}.automountServiceAccountToken) && !{pod}.automountServiceAccountToken',
            f'has({pod}.securityContext) && {pod}.securityContext.runAsNonRoot && {pod}.securityContext.runAsUser == 10001 && {pod}.securityContext.runAsGroup == 10001 && {pod}.securityContext.seccompProfile.type == "RuntimeDefault"',
            f'has({c}.securityContext) && !{c}.securityContext.allowPrivilegeEscalation && {c}.securityContext.readOnlyRootFilesystem && {c}.securityContext.capabilities.drop == ["ALL"] && (!has({c}.securityContext.capabilities.add) || {c}.securityContext.capabilities.add.size() == 0)',
            f'(!has({pod}.initContainers) || {pod}.initContainers.size() == 0) && (!has({pod}.ephemeralContainers) || {pod}.ephemeralContainers.size() == 0)',
            f'!has({c}.envFrom) && (!has({c}.env) || {c}.env.size() == 0) && (!has({c}.args) || {c}.args.size() == 0)',
            f'{pod}.volumes.exists(v, v.name == "tmp") && {pod}.volumes.all(v, (v.name == "runtime" && has(v.secret)) || (v.name == "tmp" && has(v.emptyDir) && dyn(v.emptyDir).sizeLimit == "64Mi") || (v.name == "private" && has(v.emptyDir) && dyn(v.emptyDir).sizeLimit == "16Mi"))',
            f'{c}.volumeMounts.all(v, !has(v.subPath) && !has(v.subPathExpr) && ((v.name == "runtime" && v.mountPath == "/run/projected" && has(v.readOnly) && v.readOnly) || (v.name == "tmp" && v.mountPath == "/tmp") || (v.name == "private" && v.mountPath == "/run/private")))']
        name=namespace+'-images-'+kind
        result.extend([{'apiVersion':'admissionregistration.k8s.io/v1','kind':'ValidatingAdmissionPolicy','metadata':{'name':name},
            'spec':{'failurePolicy':'Fail','matchConstraints':{'resourceRules':[{'apiGroups':['' if kind=='pods' else 'apps'],'apiVersions':['v1'],'operations':['CREATE','UPDATE'],'resources':['pods','pods/ephemeralcontainers'] if kind=='pods' else [kind]}]},
                    'matchConditions':[{'name':'candidate-namespace','expression':'object.metadata.namespace == '+json.dumps(namespace)}],
                    'validations':[{'expression':e,'message':'Integrated application contract required'} for e in expressions]}},
            {'apiVersion':'admissionregistration.k8s.io/v1','kind':'ValidatingAdmissionPolicyBinding','metadata':{'name':name},
             'spec':{'policyName':name,'validationActions':['Deny']}}])
    return result


def compile_bundle(config):
    if set(config)!={'schema_version','namespace','platform','source_commit','workloads','gateway','dependencies'} or type(config['schema_version']) is not int or config['schema_version']!=1:
        raise ValueError('Unsupported build contract')
    namespace=config['namespace']
    if not isinstance(namespace,str) or not re.fullmatch(r'traderx-security-lab-[a-z0-9-]{1,24}',namespace):raise ValueError('Separate candidate namespace required')
    if config['platform'] not in ('linux/amd64','linux/arm64') or not re.fullmatch(r'[0-9a-f]{40}',config['source_commit']):raise ValueError('Source revision and supported platform required')
    entries=config['workloads']
    if set(entries)!=set(ROLES):raise ValueError('Complete protected application role inventory required')
    if len({v['secret'] for v in entries.values()})!=len(ROLES):raise ValueError('Private configuration Secret must be unique per workload')
    if config['dependencies']!={n:{'port':p,'transport':s,'namespace':namespace} for n,(p,s) in DEPS.items()}:
        raise ValueError('Explicit same-namespace TLS dependencies required')
    gateway=config['gateway']
    if set(gateway)!={'name','namespace'} or not all(isinstance(v,str) and NAME.fullmatch(v) for v in gateway.values()) or gateway['namespace']==namespace:
        raise ValueError('Explicit separate gateway namespace required')
    source=source_manifest();commands={}
    for role,entry in sorted(entries.items()):commands[role]=image(role,entry,source,config['source_commit'],config['platform'])
    items=[{'apiVersion':'v1','kind':'Namespace','metadata':{'name':namespace,'labels':{
        'pod-security.kubernetes.io/enforce':'restricted','pod-security.kubernetes.io/enforce-version':'v1.35',
        'traderx.security-lab.profile':'integrated-core'}}}]
    items+=network(namespace,gateway)+admission(namespace,entries,commands)
    for role in sorted(entries):items+=workload(role,entries[role],commands[role],namespace)
    files={'application-core.json':encoded({'apiVersion':'v1','kind':'List','items':items})}
    migrations=[]
    for index,name in enumerate(MIGRATIONS,1):
        path=f'migrations/{index:02d}-{name}';data=(STATE/'system/sql'/name).read_bytes()
        files[path]=data;migrations.append({'path':path,'sha256':sha(data)})
    plan={'schema_version':1,'status':'staged-zero-replicas-runtime-acceptance-blocked','source_commit':config['source_commit'],
        'source_manifest':source,'platform':config['platform'],'namespace':namespace,
        'images':{n:v['image'] for n,v in sorted(entries.items())},
        'required_private_secrets':{v['secret']:v['keys'] for n,v in sorted(entries.items())},
        'dependencies':config['dependencies'],'gateway':gateway,'execution_migrations':migrations,
        'activation_order':['account-service','position-service','people-service','trade-processor','order-matcher','event-publisher','event-consumer','browser-session'],
        'required_live_gates':['owned namespace/resource and CNI checks','preprovisioned scoped SQL/broker/OIDC identities and TLS trust',
            'fresh schema and ordered execution migrations before settlement','actual private-config and reachable HTTPS listener verification',
            'finite signing-key trust provisioning/refresh','gateway WAF and operator/public route separation',
            'approved image signatures/provenance policy','telemetry/collector delivery and recovery','combined authenticated trading and negative-control outcomes'],
        'limitations':['No cluster contact, activation, image publication, Secret provisioning or data migration occurs.',
            'OCI bytes/source labels are checked for consistency; labels are not signatures or proof of behavior.',
            'Digest admission and network manifests still require Kubernetes server validation and live enforcement checks.',
            'TCP readiness is listener availability only, not verified TLS or application authorization.',
            'Secret rotation requires a fresh worker pod/config volume; no in-process credential reload is claimed.']}
    files['plan.json']=encoded(plan)
    files['bundle.json']=encoded({'files':{name:sha(data) for name,data in sorted(files.items())}})
    return files


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=('source-manifest','render','verify'))
    parser.add_argument('--input',type=Path);parser.add_argument('--output',type=Path)
    args=parser.parse_args()
    if args.action=='source-manifest':print(encoded(source_manifest()).decode(),end='');return
    if args.input is None or args.output is None:parser.error('Input and output paths required')
    files=compile_bundle(read_json(args.input))
    if args.action=='verify':
        if args.output.is_symlink() or any(p.is_symlink() for p in args.output.rglob('*')):
            raise ValueError('Deployment bundle cannot contain symlinks')
        actual={str(p.relative_to(args.output)) for p in args.output.rglob('*') if p.is_file()}
        if actual!=set(files) or any((args.output/n).is_symlink() or (args.output/n).read_bytes()!=data for n,data in files.items()):
            raise ValueError('Deployment bundle differs from verified inputs')
    else:
        args.output.mkdir(parents=True,exist_ok=False)
        for name,data in files.items():
            path=args.output/name;path.parent.mkdir(exist_ok=True);path.write_bytes(data)
    print('Integrated core bundle '+args.action+' complete; zero replicas, live acceptance remains blocked.')


if __name__=='__main__':main()
