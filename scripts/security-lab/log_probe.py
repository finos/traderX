"""Bounded synthetic log delivery probe; loopback forwarding closes in finally."""
import json
from pathlib import Path
import subprocess
import time
import urllib.parse
import urllib.request
import uuid
import collector_boundary as cb


def probe(k):
    name='lab-log-'+uuid.uuid4().hex[:10];marker='LAB_LOG_BOUNDARY_'+uuid.uuid4().hex
    root=Path(__file__).resolve().parents[2]
    image=json.loads((root/'specs/012-platform-convergence-c3/security-lab/evidence/2026-11-22-platform-image.lock.json').read_text())['image']
    pod={'apiVersion':'v1','kind':'Pod','metadata':{'name':name,'namespace':cb.APP,'labels':{'app':'lab-log-probe'}},'spec':{'automountServiceAccountToken':False,'restartPolicy':'Never',
      'securityContext':{'runAsNonRoot':True,'runAsUser':10001,'runAsGroup':10001,'seccompProfile':{'type':'RuntimeDefault'}},
      'containers':[{'name':'lab-log-probe','image':image,'command':['sh','-c','echo '+marker+'; sleep 120'],
       'securityContext':{'allowPrivilegeEscalation':False,'readOnlyRootFilesystem':True,'capabilities':{'drop':['ALL']}},
       'resources':{'requests':{'cpu':'5m','memory':'8Mi'},'limits':{'cpu':'100m','memory':'32Mi'}}}]}}
    def run(*cmd,doc=None,check=True):return subprocess.run(k+list(cmd),input=json.dumps(doc) if doc else None,text=True,capture_output=True,check=check,timeout=45)
    forward=None
    try:
        run('create','-f','-',doc=pod)
        forward=subprocess.Popen(k+['-n',cb.APP,'port-forward','service/loki','18131:3100','--address=127.0.0.1'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        query='{service="lab-log-probe",namespace="'+cb.APP+'"} |= "'+marker+'"'
        deadline=time.monotonic()+90
        while time.monotonic()<deadline:
            if forward.poll() is not None:raise RuntimeError('Loopback Loki forward could not start')
            params=urllib.parse.urlencode({'query':query,'limit':20,'start':str(int((time.time()-180)*1e9)),'end':str(int(time.time()*1e9))})
            try:
                with urllib.request.urlopen('http://127.0.0.1:18131/loki/api/v1/query_range?'+params,timeout=4) as response:result=json.load(response)
                if any(marker in line for stream in result.get('data',{}).get('result',[]) for _,line in stream.get('values',[])):
                    return {'marker':marker,'pod':name,'received_in_loki':True}
            except (OSError,ValueError):pass
            time.sleep(1)
        raise TimeoutError('Fresh log marker did not reach Loki')
    finally:
        if forward:
            forward.terminate()
            try:forward.wait(timeout=5)
            except subprocess.TimeoutExpired:forward.kill();forward.wait()
        run('-n',cb.APP,'delete','pod',name,'--ignore-not-found','--wait=false',check=False)
