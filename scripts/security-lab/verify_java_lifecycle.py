"""Actual generated messaging adapters: reconnect and credential replacement tests."""
import hashlib
import json
import os
from pathlib import Path
import queue
import subprocess
import threading
import time
import uuid
from nats_fixture import Client


def verify(builds, java_home, context, cert, passwords, private, restart):
    scripts=Path(__file__).parent;results=[]
    cases=[('trade-service','PublisherProbe','trade-api','/trades','observer'),('trade-processor','PublisherProbe','processor','/accounts/22214/trades','observer'),('order-matcher','PublisherProbe','matcher','/orders','observer'),('trade-processor','SubscriberProbe','processor','/trades','trade-api'),('order-matcher','MatcherProbe','matcher','pricing.TEST','pricer')]
    for index,(service,probe,identity,subject,peer) in enumerate(cases):
        work=private/('java-lifecycle-'+str(index));work.mkdir()
        cp=(builds/service/'build/lab-lifecycle-classpath.txt').read_text()
        source=scripts/'java-lifecycle'/f'{probe}.java'
        subprocess.run([str(java_home/'bin/javac'),'-cp',cp,'-d',str(work),str(source)],check=True,capture_output=True,timeout=30)
        command=[str(java_home/'bin/java'),'-cp',str(work)+os.pathsep+cp,probe]
        if probe in ['PublisherProbe','SubscriberProbe']:
            subprocess.run(command+['status-regression'],check=True,capture_output=True,timeout=15)
        if probe=='PublisherProbe':command.append(subject)
        user=work/'user';password=work/'password'
        for path,value in [(user,identity),(password,passwords[identity])]:path.write_text(value);path.chmod(0o600)
        env={k:v for k,v in os.environ.items() if not k.startswith(('NATS_','PROBE_'))}
        env.update(NATS_SECURITY_REQUIRED='true',NATS_ADDRESS='tls://localhost:18444',NATS_USER_FILE=str(user),NATS_PASSWORD_FILE=str(password),NATS_CA_FILE=str(cert))
        child=None;lines=queue.Queue()
        def start():
            nonlocal child,lines
            lines=queue.Queue()
            child=subprocess.Popen(command,env=env,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,bufsize=1)
            output=child.stdout;target=lines
            def drain():
                for line in output:
                    if line.startswith('LAB_'):target.put(line.strip())
            threading.Thread(target=drain,daemon=True).start()
            deadline=time.monotonic()+25
            while time.monotonic()<deadline:
                if child.poll() is not None:raise RuntimeError('Adapter exited before readiness: '+service+'/'+probe)
                try:
                    if lines.get(timeout=.2)=='LAB_READY':return
                except queue.Empty:pass
            raise TimeoutError('Adapter did not become ready: '+service+'/'+probe)
        def stop():
            if child is None:return
            if child.poll() is None:child.stdin.close()
            try:child.wait(timeout=5)
            except subprocess.TimeoutExpired:
                child.terminate()
                try:child.wait(timeout=5)
                except subprocess.TimeoutExpired:child.kill();child.wait(timeout=5)
            child.stdout.close()
        def delivery():
            sender=Client('tcp',context,cert);sender.connect(peer,passwords[peer])
            marker=str(time.time_ns()) if probe=='MatcherProbe' else uuid.uuid4().hex
            try:
                if probe=='PublisherProbe':sender.subscribe(subject)
                deadline=time.monotonic()+20
                while time.monotonic()<deadline:
                    if child.poll() is not None:raise RuntimeError('Adapter exited during recovery')
                    if probe=='PublisherProbe':
                        child.stdin.write(marker+'\n');child.stdin.flush()
                        time.sleep(.15);sender.flush()
                        if any(json.loads(m['payload']).get('payload')==marker for m in sender.messages):return
                    else:
                        body={'price':int(marker),'ticker':'TEST'} if probe=='MatcherProbe' else {'type':'String','topic':subject,'payload':marker,'from':'fixture','date':'2026-11-22T00:00:00Z'}
                        sender.publish(subject,json.dumps(body))
                        try:
                            if lines.get(timeout=.2)=='LAB_RECEIVED '+marker:return
                        except queue.Empty:pass
                    time.sleep(.1)
                raise TimeoutError('Fresh adapter marker not received: '+service+'/'+probe)
            finally:sender.close()
        try:
            start();delivery();first=child.pid
            restart(None);delivery();assert child.pid==first
            retired=passwords[identity];restart(identity)
            client=Client('tcp',context,cert)
            try:
                try:client.connect(identity,retired)
                except (PermissionError,ConnectionError):pass
                assert any('Authorization Violation' in e for e in client.errors)
            finally:client.close()
            password.write_text(passwords[identity]);stop();start();delivery();assert child.pid!=first
            results.append({'service':service,'adapter':probe,'identity':identity,'subject':subject,'same_process_reconnect':'fresh-marker-received','retired_login':'explicit-denial','rotation_after_process_replacement':'fresh-marker-received','probe_sha256':hashlib.sha256(source.read_bytes()).hexdigest()})
            print(service+'/'+probe+': reconnect and rotation passed.',flush=True)
        finally:stop()
    fingerprints={}
    for service in ['trade-service','trade-processor','order-matcher']:
        fingerprints[service]={str(path.relative_to(builds/service)):hashlib.sha256(path.read_bytes()).hexdigest() for base in ['src/main','build/classes/java/main'] for path in (builds/service/base).rglob('*') if path.is_file()}
    return {'status':'passed','cases':results,'tested_build_hashes':fingerprints,'limitations':['Actual messaging adapters with recording callbacks; matcher domain service is mocked.','No database writes, end-to-end settlement or full Spring context startup.','Broker restart invalidates sessions; Secret files reload only on process replacement.','Reconnect checks prove fresh receipt after recovery, not lossless delivery during outage.']}
