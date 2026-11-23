#!/usr/bin/env python3
"""Transactional, image-only candidate rollout in the explicitly named lab."""
import argparse
import copy
import fcntl
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
from datetime import datetime,timezone


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--runtime-dir',type=Path,default=Path('/private/tmp/traderx-security-runtime'));a=p.parse_args();root=a.runtime_dir.resolve();scripts=Path(__file__).parent.resolve()
    folder=root/'candidate-rollout';folder.mkdir(mode=0o700,exist_ok=True)
    lock=(root/'console-run.lock').open('a');fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
    state_path=folder/'state.json'
    if state_path.exists():raise ValueError('Existing candidate rollout state requires review before another rollout')
    kube=['kubectl','--kubeconfig',str(root/'kubeconfig'),'--context','kind-traderx-security-lab']
    docker=['docker','--config',str(root/'docker-client'),'--host','unix://'+str(Path.home()/'.docker/run/docker.sock')]
    def run(cmd,doc=None,timeout=180):
        return subprocess.run(cmd,input=json.dumps(doc) if doc is not None else None,text=True,capture_output=True,check=True,timeout=timeout).stdout
    def kub(*args,doc=None,timeout=180):return run(kube+list(args),doc,timeout)
    nodes=json.loads(kub('get','nodes','-o','json'))['items'];assert [n['metadata']['name'] for n in nodes]==['traderx-security-lab-control-plane']
    ns='traderx-security-lab';node='traderx-security-lab-control-plane'
    java=json.loads((root/'evidence/java-candidate-images.json').read_text());price=json.loads((root/'evidence/nats-publisher-image.json').read_text())
    proof=json.loads((root/'evidence/nats-publisher-container/nats-result.json').read_text());assert proof['status']=='passed' and proof['node_image']['image_config_id']==price['local_image_config_id']
    candidates=java['images']+[price|{'service':'price-publisher'}]
    assert {x['service'] for x in candidates}=={'trade-service','trade-processor','order-matcher','price-publisher'}
    state={'active':False,'status':'preparing','images':{},'previous':{},'checks':[],'started_at':datetime.now(timezone.utc).isoformat()};touched=[]
    def save():
        temp=folder/'state.tmp';temp.write_text(json.dumps(state,indent=2)+'\n');temp.chmod(0o600);temp.replace(state_path)
    def deployment(service):return json.loads(kub('-n',ns,'get','deployment',service,'-o','json'))
    def patch(service,old,new,pull):
        current=deployment(service);assert current['spec']['template']['spec']['containers'][0]['image']==old,'Concurrent image change'
        operations=[{'op':'test','path':'/metadata/resourceVersion','value':current['metadata']['resourceVersion']},{'op':'replace','path':'/spec/template/spec/containers/0/image','value':new},{'op':'add','path':'/spec/template/spec/containers/0/imagePullPolicy','value':pull}]
        kub('-n',ns,'patch','deployment',service,'--type=json','-p',json.dumps(operations))
        kub('-n',ns,'rollout','status','deployment/'+service,'--timeout=420s',timeout=440)
    try:
        for item in candidates:
            service=item['service'];info=json.loads(run(docker+['image','inspect',item['tag']]))[0];assert info['Id']==item['local_image_config_id']
            env=os.environ|{'DOCKER_HOST':'unix://'+str(Path.home()/'.docker/run/docker.sock'),'DOCKER_CONFIG':str(root/'docker-client')}
            subprocess.run(['kind','load','docker-image',item['tag'],'--name','traderx-security-lab'],env=env,check=True,capture_output=True,timeout=240)
            tag='docker.io/library/'+item['tag'];lines=run(docker+['exec',node,'ctr','-n','k8s.io','images','ls']).splitlines()
            matches=[line.split() for line in lines if line.split() and line.split()[0]==tag];assert len(matches)==1
            digest=matches[0][2];manifest=json.loads(run(docker+['exec',node,'ctr','-n','k8s.io','content','get',digest]));assert manifest['config']['digest']==item['local_image_config_id']
            reference=tag.split(':')[0]+'@'+digest
            run(docker+['exec',node,'ctr','-n','k8s.io','images','tag',tag,reference])
            state['images'][service]=reference
            current=deployment(service);c=current['spec']['template']['spec']['containers'][0]
            state['previous'][service]={'image':c['image'],'imagePullPolicy':c.get('imagePullPolicy','IfNotPresent')}
            path=folder/(service+'-before.json');path.write_text(json.dumps(current));path.chmod(0o600)
        state.update(active=True,status='validating');save()
        for item in candidates:
            service=item['service'];before=json.loads((folder/(service+'-before.json')).read_text());touched.append(service)
            patch(service,state['previous'][service]['image'],state['images'][service],'IfNotPresent')
            after=deployment(service)
            for obj in [before,after]:
                c=obj['spec']['template']['spec']['containers'][0];c.pop('image');c.pop('imagePullPolicy',None)
            assert before['spec']==after['spec'],'Non-image deployment settings changed'
            state['checks'].append({'service':service,'ready':True,'non_image_spec_preserved':True});save();print(service+': candidate ready; existing settings preserved.',flush=True)
        for command,log_name in [([sys.executable,str(scripts/'verify_workloads.py'),'--runtime-dir',str(root),'--output-dir',str(folder/'workloads')],'workloads.log'),([sys.executable,str(scripts/'verify_database_permissions.py'),'--runtime-dir',str(root),'--output-dir',str(folder/'sql')],'sql.log'),(['bash',str(scripts/'test-reference.sh')],'trading.log')]:
            with (folder/log_name).open('w') as log:
                subprocess.run(command,stdout=log,stderr=log,env=os.environ|{'TRADERX_SECURITY_RUNTIME':str(root)},check=True,timeout=900)
        state.update(status='passed',completed_at=datetime.now(timezone.utc).isoformat(),workload_checks='passed',sql_checks='passed',trading_smoke='passed');save()
        print('PASS: candidate Spring services, workload checks and full C3 trading smoke.',flush=True)
    except Exception as error:
        state['error_type']=type(error).__name__;state['status']='failed';state['rollback']=[]
        for service in reversed(touched):
            try:
                prior=state['previous'][service];current=deployment(service)['spec']['template']['spec']['containers'][0]['image']
                if current==state['images'][service]:patch(service,current,prior['image'],prior['imagePullPolicy'])
                elif current!=prior['image']:raise RuntimeError('Concurrent image change; rollback refused')
                state['rollback'].append({'service':service,'restored':True})
            except Exception as rollback_error:state['rollback'].append({'service':service,'restored':False,'error_type':type(rollback_error).__name__})
        state['active']=any(not item['restored'] for item in state['rollback']);save();raise

if __name__=='__main__':main()
