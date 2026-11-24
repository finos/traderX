"""Effect-based log/metric/trace/dashboard persistence and collector-boundary checks."""
import argparse
import base64
from contextlib import contextmanager
import copy
import json
from pathlib import Path
import secrets
import selectors
import subprocess
import time
import urllib.parse
import urllib.request

import bootstrap_database
import collector_boundary
import credential_store
import database_lifecycle as db
import observability_migration
from resource_operation import operation
import telemetry_lifecycle as telemetry
import workloads


@contextmanager
def forward(api,name,port):
    process=subprocess.Popen(api.command+['port-forward','-n',api.namespace,'service/'+name,f'18491:{port}','--address=127.0.0.1'],stdout=subprocess.PIPE,stderr=subprocess.DEVNULL)
    try:
        with selectors.DefaultSelector() as selector:
            selector.register(process.stdout,selectors.EVENT_READ)
            if not selector.select(timeout=15) or not process.stdout.readline().startswith(b'Forwarding from 127.0.0.1:'):
                raise RuntimeError('Owned telemetry forward failed to bind')
        def request(path,payload=None):
            headers={'Content-Type':'application/json','Accept':'application/json'}
            if name=='grafana':headers['Authorization']='Basic '+base64.b64encode(b'admin:admin').decode()
            req=urllib.request.Request('http://127.0.0.1:18491'+path,headers=headers,data=json.dumps(payload).encode() if payload is not None else None)
            with urllib.request.urlopen(req,timeout=10) as response:
                body=response.read()
                return json.loads(body) if body else {}
        yield request
    finally:
        process.terminate()
        try:process.wait(timeout=10)
        except subprocess.TimeoutExpired:process.kill();process.wait()
        process.stdout.close()


def until(check,seconds=90):
    deadline=time.monotonic()+seconds
    while True:
        try:
            value=check()
            if value:return value
        except (OSError,ValueError):pass
        if time.monotonic()>deadline:raise TimeoutError('Telemetry outcome not observed within bound')
        time.sleep(1)


def boundary(api,reference,credentials):
    infra=telemetry.infra_namespace(api.namespace)
    ds=next(d for d in telemetry.resources(reference,credentials,api.namespace) if d['kind']=='DaemonSet')
    good={'apiVersion':'v1','kind':'Pod','metadata':{'name':'collector-policy-check','namespace':infra},'spec':ds['spec']['template']['spec']}
    good['spec'].pop('nodeSelector')
    api.run(['create','--dry-run=server','-f','-'],json.dumps(good))
    for mutate in ('writable-host','host-root','long-token'):
        bad=copy.deepcopy(good)
        if mutate=='writable-host':bad['spec']['containers'][0]['volumeMounts'][1]['readOnly']=False
        if mutate=='host-root':bad['spec']['volumes'][1]['hostPath']['path']='/'
        if mutate=='long-token':bad['spec']['volumes'][3]['projected']['sources'][0]['serviceAccountToken']['expirationSeconds']=86400
        result=subprocess.run(api.command+['create','--dry-run=server','-f','-'],input=json.dumps(bad),capture_output=True,text=True,timeout=45)
        if result.returncode==0 or 'traderx-lab-log-collector-pods-' not in result.stderr:raise RuntimeError('Collector exception was not constrained')
    identity='system:serviceaccount:'+infra+':'+collector_boundary.SA
    for verb,resource,allowed in [('list','pods',True),('list','nodes',True),('list','namespaces',True),('get','secrets',False),('create','pods',False),('update','deployments',False)]:
        result=subprocess.run(api.command+['auth','can-i',verb,resource,'-n',api.namespace,'--as='+identity,
            '--as-group=system:serviceaccounts','--as-group=system:serviceaccounts:'+infra,'--as-group=system:authenticated'],capture_output=True,text=True,timeout=45)
        if result.stdout.strip()!=('yes' if allowed else 'no'):raise RuntimeError('Collector RBAC differs from expected boundary')
    return {'admission_denials':['writable-host','host-root','long-token'],'rbac_checks':6}


def campaign(api,reference,credentials,runtime):
    telemetry.start(api,reference,credentials,runtime)
    restrictions=boundary(api,reference,credentials)
    running_business=[d['metadata']['name'] for d in json.loads(api.run(['get','deployments','-n',api.namespace,'-o','json']))['items'] if d['metadata']['name'] in workloads.NAMES and d['spec'].get('replicas',0)>0]
    uid='lab'+secrets.token_hex(6);marker='STATE019_LOG_'+secrets.token_hex(12)
    image=json.loads((Path(__file__).resolve().parents[2]/'specs/012-platform-convergence-c3/security-lab/evidence/2026-11-22-platform-image.lock.json').read_text())['image']
    pod={'apiVersion':'v1','kind':'Pod','metadata':{'name':uid,'namespace':api.namespace,'labels':{db.OWNER:db.identity(credentials),'app':'lab-log-probe'}},'spec':{'automountServiceAccountToken':False,'restartPolicy':'Never',
        'securityContext':{'runAsNonRoot':True,'runAsUser':10001,'runAsGroup':10001,'seccompProfile':{'type':'RuntimeDefault'}},
        'containers':[{'name':'lab-log-probe','image':image,'command':['sh','-c','echo '+marker+'; sleep 5'],
            'securityContext':{'allowPrivilegeEscalation':False,'readOnlyRootFilesystem':True,'capabilities':{'drop':['ALL']}},
            'resources':{'requests':{'cpu':'5m','memory':'8Mi'},'limits':{'cpu':'100m','memory':'32Mi'}}}]}}
    api.create(pod)
    try:
        with forward(api,'grafana',3000) as request:
            request('/grafana/api/dashboards/db',{'dashboard':{'id':None,'uid':uid,'title':'State 019 persistence '+uid,'panels':[],'schemaVersion':39},'overwrite':False})
            if request('/grafana/api/dashboards/uid/'+uid)['dashboard']['uid']!=uid:raise RuntimeError('Grafana canary missing')
        logpath='/loki/api/v1/query_range?'+urllib.parse.urlencode({'query':'{namespace="'+api.namespace+'",service="lab-log-probe"} |= "'+marker+'"','start':str(time.time_ns()-180_000_000_000),'end':str(time.time_ns()+180_000_000_000),'limit':20})
        def has_log(data):return any(marker in line for stream in data.get('data',{}).get('result',[]) for _,line in stream.get('values',[]))
        with forward(api,'loki',3100) as request:until(lambda:has_log(request(logpath)))
        trace_id=secrets.token_hex(16);span_id=secrets.token_hex(8);now=time.time_ns()
        trace={'resourceSpans':[{'resource':{'attributes':[{'key':'service.name','value':{'stringValue':'state019-telemetry-check'}}]},'scopeSpans':[{'scope':{'name':'state019-lab'},'spans':[{'traceId':trace_id,'spanId':span_id,'name':uid,'kind':1,'startTimeUnixNano':str(now-1000000),'endTimeUnixNano':str(now),'status':{'code':1}}]}]}]}
        with forward(api,'otel-collector',4318) as request:
            result=request('/v1/traces',trace)
            if result.get('partialSuccess',{}).get('rejectedSpans',0) not in (0,'0'):raise RuntimeError('OTLP span rejected')
        with forward(api,'tempo',3200) as request:
            span_ids=until(lambda:observability_migration.span_ids(request('/api/traces/'+trace_id)))
        with forward(api,'prometheus',9090) as request:
            until(lambda:request('/prometheus/api/v1/query?query=up%7Bjob%3D%22prometheus%22%7D')['data']['result'])
            metric_path='/prometheus/api/v1/query?'+urllib.parse.urlencode({'query':'up{job="prometheus"}','time':str(time.time())})
            metric=request(metric_path)['data']['result']
            if len(metric)!=1 or metric[0]['value'][1]!='1':raise RuntimeError('Prometheus self scrape is not healthy')
        pvcs={name:api.get('pvc','lab-'+name+'-data',api.namespace)['metadata']['uid'] for name in telemetry.ORDER}
        old_pods={p['metadata']['labels']['app']:p['metadata']['uid'] for p in json.loads(api.run(['get','pods','-n',api.namespace,'-o','json']))['items'] if p['metadata'].get('labels',{}).get('app') in telemetry.ORDER}
        # Graceful stop flushes buffered telemetry before persistence is checked on new pods.
        telemetry.stop(api,credentials)
        telemetry.start(api,reference,credentials,runtime)
        with forward(api,'grafana',3000) as request:
            if request('/grafana/api/dashboards/uid/'+uid)['dashboard']['uid']!=uid:raise RuntimeError('Grafana lost dashboard')
        with forward(api,'loki',3100) as request:until(lambda:has_log(request(logpath)))
        with forward(api,'tempo',3200) as request:
            until(lambda:set(span_ids).issubset(observability_migration.span_ids(request('/api/traces/'+trace_id))))
        with forward(api,'prometheus',9090) as request:
            if request(metric_path)['data']['result']!=metric:raise RuntimeError('Historical metric changed')
        new_pods={p['metadata']['labels']['app']:p['metadata']['uid'] for p in json.loads(api.run(['get','pods','-n',api.namespace,'-o','json']))['items'] if p['metadata'].get('labels',{}).get('app') in telemetry.ORDER}
        if set(old_pods)!=set(telemetry.ORDER) or set(new_pods)!=set(old_pods) or any(new_pods[n]==old_pods[n] for n in old_pods):raise RuntimeError('Telemetry pod recreation not proven')
        if any(api.get('pvc','lab-'+n+'-data',api.namespace)['metadata']['uid']!=uid for n,uid in pvcs.items()):raise RuntimeError('Telemetry PVC replaced')
        return {'status':'passed','scope':'Live telemetry lifecycle','business_services_running':sorted(running_business),'namespace':api.namespace,
            'dashboard_uid':uid,'log_marker':marker,'trace_id':trace_id,'span_ids':span_ids,'historical_metric':metric,
            'pvcs':pvcs,'old_pods':old_pods,'new_pods':new_pods,'collector_boundary':restrictions,
            'limitations':['Collector checkpoints use emptyDir; log replay/duplication after restart is possible.',
                'Grafana retains the reference demo login; operator authentication remains pending.',
                'Persistent logs do not establish tamper-resistant audit evidence; network/operator controls remain pending.',
                'No continuous-load, zero-loss telemetry or production durability claim.']}
    finally:
        current=api.get('pod',pod['metadata']['name'],api.namespace)
        if current and current['metadata'].get('labels',{}).get(db.OWNER)==db.identity(credentials):
            api.run(['delete','pod',pod['metadata']['name'],'-n',api.namespace,'--wait=false'])


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for arg in ('store','runtime-dir','kubeconfig','output'):parser.add_argument('--'+arg,type=Path,required=True)
    for arg in ('context','cluster-uid','namespace'):parser.add_argument('--'+arg,required=True)
    args=parser.parse_args()
    if args.output.exists():raise ValueError('Evidence output exists')
    credentials=credential_store.load(args.store);api=db.Kubernetes(args.kubeconfig,args.context,args.cluster_uid,args.namespace)
    with operation(args.runtime_dir,'acceptance'):
        result=campaign(api,bootstrap_database.pinned_reference(),credentials,args.runtime_dir)
        with args.output.open('x') as target:json.dump(result,target,indent=2);target.write('\n')
    print('Log, trace, metric and dashboard persisted across telemetry pod recreation; collector boundaries passed.')


if __name__=='__main__':main()
