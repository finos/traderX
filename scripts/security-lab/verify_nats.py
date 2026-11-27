#!/usr/bin/env python3
"""Repeatable synthetic NATS permissions over verified TLS and WebSocket TLS."""
import argparse
import fcntl
from contextlib import ExitStack
from datetime import datetime,timezone
import hashlib
import json
import os
from pathlib import Path
import secrets
import ssl
import subprocess
import tempfile
import time
import uuid
from nats_fixture import IMAGE,PERMISSIONS,Client,config

NAME='traderx-security-nats-fixture';NETWORK='traderx-security-nats-check';LABEL='traderx.security-lab.nats'

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--runtime-dir',type=Path,default=Path('/private/tmp/traderx-security-runtime'));p.add_argument('--java-service-builds',type=Path);p.add_argument('--node-image');p.add_argument('--java-client-jar',type=Path);p.add_argument('--java-home',type=Path);p.add_argument('--node-publisher-dir',type=Path);p.add_argument('--output-dir',type=Path,required=True);a=p.parse_args();root=a.runtime_dir.resolve();root.mkdir(exist_ok=True);private=root/'nats-fixture';private.mkdir(mode=0o700,exist_ok=True)
    lock=(private/'fixture.lock').open('a')
    fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
    docker=['docker','--config',str(root/'docker-client'),'--host','unix://'+str(Path.home()/'.docker/run/docker.sock')]
    def run(*cmd,required=True,timeout=120):
        r=subprocess.run(docker+list(cmd),text=True,capture_output=True,timeout=timeout)
        if required and r.returncode:raise RuntimeError(r.stderr)
        return r
    def remove_owned(kind,name):
        r=run(kind,'inspect',name,required=False)
        if r.returncode:
            if 'No such' not in r.stderr and f'network {name} not found' not in r.stderr:raise RuntimeError('Could not inspect fixture ownership')
            return
        d=json.loads(r.stdout)[0];labels=d.get('Labels') if kind=='network' else d['Config'].get('Labels')
        if (labels or {}).get(LABEL)!='true':raise ValueError('Refusing unrelated fixture-name collision')
        if kind=='container':run('rm','-f',name)
        else:run('network','rm',name)
    remove_owned('container',NAME);remove_owned('network',NETWORK)
    if run('image','inspect',IMAGE,required=False).returncode:run('pull',IMAGE)
    image_id=json.loads(run('image','inspect',IMAGE).stdout)[0]['Id']
    node_result=None;java_result=None;image_result=None;java_lifecycle=None
    results=[];run_id=uuid.uuid4().hex;created=False
    with tempfile.TemporaryDirectory(prefix='run-',dir=private) as temp:
        mount=Path(temp)/'broker';mount.mkdir(mode=0o755)
        passwords={name:secrets.token_hex(24) for name in PERMISSIONS};cfg=config(passwords)
        (mount/'nats.json').write_text(json.dumps(cfg));(mount/'nats.json').chmod(0o644)
        subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-keyout',str(mount/'key.pem'),'-out',str(mount/'cert.pem'),'-days','1','-subj','/CN=localhost','-addext','subjectAltName=DNS:localhost,IP:127.0.0.1'],capture_output=True,check=True,timeout=30)
        (mount/'key.pem').chmod(0o644);(mount/'cert.pem').chmod(0o644)
        cert_hash=hashlib.sha256((mount/'cert.pem').read_bytes()).hexdigest();context=ssl.create_default_context(cafile=str(mount/'cert.pem'))
        try:
            run('network','create','--label',LABEL+'=true',NETWORK);created=True
            run('run','-d','--name',NAME,'--label',LABEL+'=true','--network',NETWORK,'--read-only','--cap-drop=ALL','--security-opt=no-new-privileges','--user','10001:10001','--memory','128m','--cpus','0.5','--pids-limit','64','--mount',f'type=bind,src={mount},dst=/lab,readonly','-p','127.0.0.1:18444:4222','-p','127.0.0.1:18445:8443',IMAGE,'-c','/lab/nats.json')
            deadline=time.monotonic()+30
            while True:
                try:c=Client('tcp',context,mount/'cert.pem');version=c.info['version'];c.close();break
                except (OSError,ConnectionError):
                    if time.monotonic()>deadline:raise TimeoutError('Pinned fixture broker did not become ready')
                    time.sleep(.25)
            inspected=json.loads(run('inspect',NAME).stdout)[0];host=inspected['HostConfig']
            assert host['ReadonlyRootfs'] and host['CapDrop']==['ALL'] and inspected['Config']['User']=='10001:10001'
            assert set(host['PortBindings'])=={'4222/tcp','8443/tcp'}
            assert all(p['HostIp']=='127.0.0.1' for values in host['PortBindings'].values() for p in values)
            def restart_broker(identity=None):
                if identity:
                    passwords[identity]=secrets.token_hex(24)
                    (mount/'nats.json').write_text(json.dumps(config(passwords)))
                run('restart',NAME)
                deadline=time.monotonic()+30
                while True:
                    try:
                        c=Client('tcp',context,mount/'cert.pem');c.close();break
                    except (OSError,ConnectionError):
                        if time.monotonic()>deadline:raise TimeoutError('Fixture restart failed')
                        time.sleep(.1)
            if a.java_service_builds:
                if not a.java_home:raise ValueError('--java-home required')
                from verify_java_lifecycle import verify as verify_lifecycle_java
                java_lifecycle=verify_lifecycle_java(a.java_service_builds,a.java_home,context,mount/'cert.pem',passwords,Path(temp),restart_broker)
            if a.node_image:
                from verify_node_image import verify as verify_image
                image_result=verify_image(a.node_image,context,mount/'cert.pem',passwords,Path(temp),run,NAME)
                print('Candidate publisher image: authenticated TLS delivery passed.',flush=True)
            if a.java_client_jar:
                if not a.java_home:raise ValueError('--java-home required for Java checks')
                from verify_java_nats import verify as verify_java
                java_result=verify_java(a.java_client_jar,a.java_home,passwords,mount/'cert.pem',Path(temp))
                print('Java TLS identity, delivery and certificate checks passed.',flush=True)
            if a.node_publisher_dir:
                from verify_node_publisher import verify
                node_result=verify(a.node_publisher_dir,context,mount/'cert.pem',passwords,Path(temp))
                print('Real Node publisher: authenticated TLS price delivery passed.',flush=True)
                def restart_fixture(rotate):
                    if rotate:
                        passwords['pricer']=secrets.token_hex(24)
                        (mount/'nats.json').write_text(json.dumps(config(passwords)))
                    run('restart',NAME)
                    deadline=time.monotonic()+30
                    while True:
                        try:
                            c=Client('tcp',context,mount/'cert.pem');c.close();break
                        except (OSError,ConnectionError):
                            if time.monotonic()>deadline:raise TimeoutError('Fixture restart failed')
                            time.sleep(.1)
                from verify_node_lifecycle import verify as verify_lifecycle
                node_result['lifecycle']=verify_lifecycle(a.node_publisher_dir,context,mount/'cert.pem',passwords,Path(temp),restart_fixture)
                print('Node publisher reconnect and password rotation passed.',flush=True)
            for transport in ['tcp','wss']:
                def row(case,identity,outcome,**more):results.append({'transport':transport,'case':case,'identity':identity,'outcome':outcome,**more})
                for user,password,case in [(None,None,'anonymous'),('browser-a','wrong-fixture-password','invalid-credential')]:
                    c=Client(transport,context,mount/'cert.pem')
                    try:
                        try:c.connect(user,password)
                        except (PermissionError,ConnectionError):pass
                        assert any('Authorization Violation' in e for e in c.errors),'No explicit broker authentication denial'
                        row(case,user or 'anonymous','denied',broker_error=c.errors[-1])
                    finally:c.close()
                with ExitStack() as stack:
                    def client(identity):
                        c=Client(transport,context,mount/'cert.pem');stack.callback(c.close);c.connect(identity,passwords[identity]);return c
                    users={name:client(name) for name in PERMISSIONS};observer=users['observer']
                    for subject in ['pricing.TEST','/trades','/orders','/accounts/22214/trades','/accounts/22214/positions','/accounts/22214/orders','/accounts/62654/trades']:observer.subscribe(subject)
                    def received(c,subject,marker):
                        deadline=time.monotonic()+2
                        while time.monotonic()<deadline:
                            c.flush()
                            if any(m['subject']==subject and m['payload']==marker for m in c.messages):return True
                            time.sleep(.05)
                        return False
                    def deliver(publisher,subscriber,subject,case):
                        target=users[subscriber];target.subscribe(subject);marker=run_id+':'+transport+':'+case
                        before=len(users[publisher].errors);users[publisher].publish(subject,marker);assert len(users[publisher].errors)==before
                        assert received(target,subject,marker) and received(observer,subject,marker),'Permitted message missing'
                        row(case,subscriber,'delivered',subject=subject,publisher=publisher,marker=marker)
                    deliver('pricer','browser-a','pricing.TEST','market-data')
                    deliver('processor','browser-a','/accounts/22214/trades','own-account-a')
                    deliver('processor','browser-b','/accounts/62654/trades','own-account-b')
                    deliver('trade-api','processor','/trades','trade-command')
                    deliver('matcher','browser-a','/accounts/22214/orders','order-event')
                    def deny_publish(identity,subject,case):
                        c=users[identity];before=len(c.errors);marker=run_id+':'+transport+':'+case;c.publish(subject,marker)
                        assert len(c.errors)>before and any('Permissions Violation for Publish' in e and subject in e for e in c.errors[before:]),'No publish authorization denial'
                        assert not received(observer,subject,marker),'Denied publication was delivered'
                        row(case,identity,'denied',subject=subject,broker_error=c.errors[-1],observer_received=False,observation_seconds=2,marker=marker)
                    deny_publish('browser-a','/trades','browser-command-publication')
                    deny_publish('pricer','/trades','pricer-command-publication')
                    deny_publish('trade-api','/accounts/22214/trades','api-forged-account-event')
                    for identity,subject,case in [('browser-a','/accounts/62654/trades','cross-account-subscription'),('browser-a','/orders','global-orders-subscription'),('processor','pricing.TEST','processor-price-subscription')]:
                        c=users[identity];before=len(c.errors);c.subscribe(subject)
                        assert len(c.errors)>before and any('Permissions Violation for Subscription' in e and subject in e for e in c.errors[before:]),'No subscription authorization denial'
                        marker=run_id+':'+transport+':'+case;publisher='processor' if subject.endswith('/trades') else 'matcher' if subject=='/orders' else 'pricer'
                        users[publisher].publish(subject,marker);assert received(observer,subject,marker)
                        assert not received(c,subject,marker),'Unauthorized subscription received event'
                        row(case,identity,'denied',subject=subject,broker_error=c.errors[-1],observer_received=True,unauthorized_received=False,observation_seconds=2)
                    reconnect=client('browser-a');users['browser-a']=reconnect
                    deliver('pricer','browser-a','pricing.TEST','reconnect-market-data')
                print(transport+': authenticated delivery, permission denials and reconnect passed.',flush=True)
        finally:
            remove_owned('container',NAME)
            if created:remove_owned('network',NETWORK)
    result={'scenario':'nats-permissions-fixture','status':'passed','recorded_at':datetime.now(timezone.utc).isoformat(),'run_id':run_id,'image':IMAGE,'image_id':image_id,'server_version':version,'certificate_sha256':cert_hash,'tls_trust_and_hostname_verified':True,'permissions':PERMISSIONS,'results':results,'node_publisher':node_result,'java_clients':java_result,'java_adapter_lifecycle':java_lifecycle,'node_image':image_result,'cleanup_verified':True,'limitations':['Isolated synthetic broker; live C3 broker is unchanged and remains unauthenticated.','WSS protocol client uses synthetic browser identities, not real user OIDC or token issuance.','Exact subjects cover two synthetic accounts; no dynamic-account authorization claim.','Absence of delivery measured after broker flushes over a bounded two-second interval; no trading consumers or downstream trade effects in this fixture.','Private fixture network is not a demonstration of enforced outbound isolation.'],'source_hashes':{name:hashlib.sha256((Path(__file__).parent/name).read_bytes()).hexdigest() for name in ['nats_fixture.py','verify_nats.py','requirements-nats.txt']+(['verify_node_publisher.py','verify_node_lifecycle.py'] if a.node_publisher_dir else [])+(['verify_java_nats.py','JavaNatsProbe.java'] if a.java_client_jar else [])+(['verify_node_image.py'] if a.node_image else [])+(['verify_java_lifecycle.py'] if a.java_service_builds else [])}}
    a.output_dir.mkdir(parents=True,exist_ok=True);(a.output_dir/'nats-result.json').write_text(json.dumps(result,indent=2)+'\n');print('PASS: NATS fixture removed; structured evidence saved.',flush=True)

if __name__=='__main__':main()
