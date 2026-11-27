"""Private checkpoint utilities for the local observability migration."""
from contextlib import contextmanager
import base64
import hashlib
import json
from pathlib import PurePosixPath
import subprocess
import tarfile
import time
import urllib.parse
import urllib.request
import observability_workloads as obs
from log_probe import probe


def archive_manifest(path,roots):
    prefixes=[r.lstrip('/') for r in roots];files={}
    with tarfile.open(path,'r:') as archive:
        for member in archive:
            p=PurePosixPath(member.name);name=str(p)
            if p.is_absolute() or '..' in p.parts or '\n' in name or not any(name==root or name.startswith(root+'/') for root in prefixes):raise ValueError('Unsafe archive path')
            if member.isdir():continue
            if not member.isfile():raise ValueError('Only directories and regular data files are accepted')
            stream=archive.extractfile(member);digest=hashlib.sha256()
            while chunk:=stream.read(1024*1024):digest.update(chunk)
            if name in files:raise ValueError('Duplicate archive entry')
            files[name]=digest.hexdigest()
    if not files:raise ValueError('Empty data checkpoint')
    return files


@contextmanager
def forward(k,name):
    port=obs.HEALTH[name][1]
    process=subprocess.Popen(k+['-n',obs.NS,'port-forward','service/'+name,f'18132:{port}','--address=127.0.0.1'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    def get(path):
        headers={'Accept':'application/json'}
        if name=='grafana':headers['Authorization']='Basic '+base64.b64encode(b'admin:admin').decode()
        deadline=time.monotonic()+20
        while True:
            if process.poll() is not None:raise RuntimeError('Local store forward failed')
            try:
                with urllib.request.urlopen(urllib.request.Request('http://127.0.0.1:18132'+path,headers=headers),timeout=5) as response:return json.load(response)
            except OSError:
                if time.monotonic()>=deadline:raise
                time.sleep(0.25)
    try:yield get
    finally:
        process.terminate()
        try:process.wait(timeout=5)
        except subprocess.TimeoutExpired:process.kill();process.wait()


def semantic_before(k,name):
    if name=='loki':
        marker=probe(k)['marker'];start=int((time.time()-300)*1e9);end=int((time.time()+120)*1e9)
        return {'marker':marker,'path':'/loki/api/v1/query_range?'+urllib.parse.urlencode({'query':'{service="lab-log-probe"} |= "'+marker+'"','start':str(start),'end':str(end),'limit':20})}
    with forward(k,name) as get:
        if name=='grafana':
            path='/grafana/api/search?type=dash-db';data=get(path);uids=sorted(d['uid'] for d in data)
            if not uids:raise ValueError('No dashboards to preserve')
            return {'path':path,'dashboard_uids':uids}
        if name=='prometheus':
            path='/prometheus/api/v1/query?'+urllib.parse.urlencode({'query':'up','time':str(time.time()-30)})
            result=get(path)['data']['result']
            if not result:raise ValueError('No historical metrics to preserve')
            return {'path':path,'result':result}
        traces=get('/api/search?limit=5').get('traces',[])
        if not traces:raise ValueError('No existing Tempo trace to preserve')
        trace_id=traces[0]['traceID'];path='/api/traces/'+trace_id
        data=get(path)
        if not span_ids(data):raise ValueError('No trace span IDs to preserve')
        return {'path':path,'trace_id':trace_id,'span_ids':span_ids(data)}


def span_ids(value):
    found=[]
    if isinstance(value,dict):
        for key,item in value.items():
            if key in ['spanId','spanID','span_id']:found.append(item)
            else:found.extend(span_ids(item))
    elif isinstance(value,list):
        for item in value:found.extend(span_ids(item))
    return sorted(set(found))


def semantic_after(k,name,before):
    with forward(k,name) as get:data=get(before['path'])
    if name=='grafana':assert sorted(d['uid'] for d in data)==before['dashboard_uids']
    elif name=='prometheus':
        normalize=lambda rows:sorted(json.dumps(r,sort_keys=True) for r in rows)
        assert normalize(data['data']['result'])==normalize(before['result'])
    elif name=='loki':assert any(before['marker'] in line for stream in data['data']['result'] for _,line in stream['values'])
    else:
        assert before['span_ids'] and set(before['span_ids']).issubset(span_ids(data))
    return {'retained_historical_data_verified':True,'check':{'grafana':'dashboard UIDs','prometheus':'fixed-time up vector','loki':'existing log marker','tempo':'existing trace span IDs'}[name]}
