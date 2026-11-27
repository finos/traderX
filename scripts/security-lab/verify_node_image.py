"""Verify the built publisher image in the isolated broker's network namespace."""
import json
from pathlib import Path
import time
from nats_fixture import Client


def verify(image, context, cert, passwords, private, docker, broker):
    if not image.startswith('sha256:') or len(image)!=71:raise ValueError('Local immutable image config ID required')
    name='traderx-security-nats-publisher';label='traderx.security-lab.nats'
    found=docker('container','inspect',name,required=False)
    if found.returncode==0:raise RuntimeError('Candidate test container already exists; refusing collision')
    if 'No such' not in found.stderr:raise RuntimeError('Cannot verify candidate name availability')
    mount=private/'image-secrets';mount.mkdir(mode=0o755)
    for filename,value in [('user','pricer'),('password',passwords['pricer']),('ca.pem',cert.read_text())]:
        p=mount/filename;p.write_text(value);p.chmod(0o644)
    observer=Client('tcp',context,cert);observer.connect('observer',passwords['observer']);observer.subscribe('pricing.AAPL')
    try:
        docker('run','-d','--name',name,'--label',label+'=true','--network','container:'+broker,'--read-only','--cap-drop=ALL','--security-opt=no-new-privileges','--memory','256m','--cpus','0.5','--pids-limit','64','--mount',f'type=bind,src={mount},dst=/lab,readonly','-e','NATS_SECURITY_REQUIRED=true','-e','NATS_ADDRESS=tls://localhost:4222','-e','NATS_USER_FILE=/lab/user','-e','NATS_PASSWORD_FILE=/lab/password','-e','NATS_CA_FILE=/lab/ca.pem','-e','PRICE_BOOTSTRAP_MODE=snapshot','-e','PRICE_TICKERS=AAPL','-e','PUBLISH_INTERVAL_MIN_MS=100','-e','PUBLISH_INTERVAL_MAX_MS=100',image)
        deadline=time.monotonic()+40
        while time.monotonic()<deadline:
            observer.flush()
            if observer.messages:break
            info=json.loads(docker('inspect',name).stdout)[0]
            if not info['State']['Running']:raise RuntimeError('Candidate publisher exited before delivery')
            time.sleep(.2)
        assert observer.messages,'Candidate image did not deliver a price'
        payload=json.loads(observer.messages[-1]['payload']);assert payload['payload']['ticker']=='AAPL'
        check="fetch('http://127.0.0.1:18100/health').then(async r=>{if(!r.ok||(await r.json()).status!=='ok')process.exit(1)}).catch(()=>process.exit(1))"
        docker('exec',name,'node','-e',check)
        info=json.loads(docker('inspect',name).stdout)[0]
        assert info['Image']==image and info['Config']['User']=='node' and info['HostConfig']['ReadonlyRootfs']
        return {'status':'passed','image_config_id':image,'authenticated_tls_delivery':'pricing.AAPL','health':'ok','user':'node','root_filesystem':'read-only','live_deployment_changed':False,'limitations':['Candidate runs under AMD64 emulation on this ARM64 host.','Container delivery test does not establish full live C3 trading, image signing or admission.']}
    finally:
        observer.close()
        found=docker('container','inspect',name,required=False)
        if found.returncode==0:
            assert json.loads(found.stdout)[0]['Config']['Labels'].get(label)=='true'
            docker('rm','-f',name)
