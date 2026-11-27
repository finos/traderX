"""Compile the canonical Java security helper and test real JNATS TLS connections."""
import hashlib
import json
import os
from pathlib import Path
import socket
import ssl
import subprocess
import threading


def verify(jar, java_home, passwords, cert, private):
    root=Path(__file__).resolve().parents[2]
    source=root/'specs/006-messaging-nats-replacement/generation/nats/NatsSecurity.java'
    probe=Path(__file__).with_name('JavaNatsProbe.java')
    classes=private/'classes';classes.mkdir()
    subprocess.run([str(java_home/'bin/javac'),'-cp',str(jar),'-d',str(classes),str(source),str(probe)],check=True,capture_output=True,timeout=30)
    command=[str(java_home/'bin/java'),'-cp',str(classes)+os.pathsep+str(jar),'JavaNatsProbe']
    env={k:v for k,v in os.environ.items() if not k.startswith(('NATS_','PROBE_'))}
    subprocess.run(command+['legacy'],env=env,check=True,capture_output=True,timeout=10)
    for identity,password in passwords.items():
        for suffix,value in [('user',identity),('password',password)]:
            p=private/(identity+'-'+suffix);p.write_text(value);p.chmod(0o600)
    env.update(NATS_SECURITY_REQUIRED='true',NATS_ADDRESS='tls://localhost:18444',NATS_CA_FILE=str(cert))
    results=[]
    for identity,mode,subject,peer in [('pricer','publish','pricing.TEST','observer'),('trade-api','publish','/trades','observer'),('processor','publish','/accounts/22214/trades','observer'),('matcher','publish','/orders','observer'),('processor','subscribe','/trades','trade-api'),('matcher','subscribe','pricing.TEST','pricer')]:
        current=env|{'NATS_USER_FILE':str(private/(identity+'-user')),'NATS_PASSWORD_FILE':str(private/(identity+'-password')),'PROBE_PEER_USER':str(private/(peer+'-user')),'PROBE_PEER_PASSWORD':str(private/(peer+'-password'))}
        p=subprocess.run(command+[mode,subject],env=current,capture_output=True,text=True,timeout=20)
        if p.returncode:raise RuntimeError('Java permitted delivery failed: '+identity+' '+p.stderr)
        results.append({'identity':identity,'mode':mode,'subject':subject,'result':'delivered'})
    env.update(NATS_USER_FILE=str(private/'pricer-user'),NATS_PASSWORD_FILE=str(private/'pricer-password'))
    bad=private/'bad-password';bad.write_text('incorrect-synthetic');bad.chmod(0o600)
    other_cert=private/'other.pem';other_key=private/'other.key'
    subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-keyout',str(other_key),'-out',str(other_cert),'-days','1','-subj','/CN=wrong.invalid','-addext','subjectAltName=DNS:wrong.invalid'],check=True,capture_output=True,timeout=30)
    def rejected(case,changes):
        p=subprocess.run(command+['connect'],env=env|changes,capture_output=True,text=True,timeout=20)
        if p.returncode!=2 or 'REJECTED' not in p.stderr:raise AssertionError('Java did not reject '+case)
        assert all(value not in p.stdout+p.stderr for value in passwords.values())
        results.append({'case':case,'result':'rejected'})
    rejected('wrong-password',{'NATS_PASSWORD_FILE':str(bad)})
    rejected('untrusted-ca',{'NATS_CA_FILE':str(other_cert)})
    # Trusted CA but wrong DNS SAN: exercise endpoint verification independently.
    listener=socket.socket();listener.bind(('127.0.0.1',0));listener.listen();listener.settimeout(10)
    port=listener.getsockname()[1];context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);context.load_cert_chain(other_cert,other_key)
    seen=[]
    def server():
        try:
            connection,_=listener.accept()
            with connection:
                try:
                    with context.wrap_socket(connection,server_side=True) as secured:
                        seen.append('accepted');secured.sendall(b'INFO {"server_id":"wrong-host","max_payload":4096}\r\n')
                except ssl.SSLError:seen.append('tls-rejected')
        except OSError:seen.append('no-connection')
    thread=threading.Thread(target=server);thread.start()
    try:rejected('wrong-hostname',{'NATS_ADDRESS':f'tls://localhost:{port}','NATS_CA_FILE':str(other_cert)})
    finally:thread.join(timeout=12);listener.close()
    assert seen==['tls-rejected'],'Hostname failure must occur during TLS, not later protocol processing'
    return {'status':'passed','cases':results,'legacy_configuration':'passed','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'probe_sha256':hashlib.sha256(probe.read_bytes()).hexdigest(),'jnats_jar_sha256':hashlib.sha256(jar.read_bytes()).hexdigest(),'limitation':'Real JNATS helper probes; complete Spring application builds, lifecycle/reconnect and rotated credentials remain separate gates.'}
