#!/usr/bin/env python3
"""Serve/stop the bounded persistent localhost browser lab without starting C3."""
import argparse
from datetime import datetime,timezone,timedelta
import hashlib
import json
import os
from pathlib import Path
import secrets
import signal
import shutil
import socket
import ssl
import subprocess
import threading
import time
import urllib.request
import uuid
from account_dev import docker
from account_oidc import replace_trust
from browser_session import BrowserServer,ORIGIN,CALLBACK
from identity_fixture import IMAGE,BASE,ISSUER,CLIENT,SUBJECTS,TokenVerifier,realm
from resource_operation import operation
from verify_identity import NAME,NETWORK,LABEL


def process_identity(pid):
    return subprocess.run(['ps','-p',str(pid),'-o','lstart=','-o','command='],capture_output=True,text=True,check=True,timeout=5).stdout.strip()


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('action',choices=['serve','stop','status'])
    parser.add_argument('--runtime-dir',type=Path,default=Path('/private/tmp/traderx-security-runtime'))
    parser.add_argument('--hours',type=float,default=4)
    args=parser.parse_args();runtime=args.runtime_dir.resolve();status_file=runtime/'browser-lab.json'
    if args.action=='status':print(status_file.read_text());return
    if args.action=='stop':
        state=json.loads(status_file.read_text())
        if state['status'] not in ('starting','ready'):raise ValueError('Browser lab is not running')
        if process_identity(state['pid'])!=state['process_identity']:raise ValueError('Process identity changed; refusing signal')
        os.kill(state['pid'],signal.SIGTERM);print('Requested graceful browser-lab shutdown.');return
    if not 0<args.hours<=8:raise ValueError('Duration must be within eight hours')
    os.umask(0o077);runtime.mkdir(mode=0o700,exist_ok=True)
    stopping=threading.Event()
    for sig in (signal.SIGTERM,signal.SIGINT):signal.signal(sig,lambda *_:stopping.set())
    with operation(runtime,'fixture'):
        for port in (18446,18447):
            with socket.socket() as check:check.bind(('127.0.0.1',port))
        private=runtime/'browser-runs'/uuid.uuid4().hex;private.mkdir(parents=True,mode=0o700)
        mount=private/'provider';mount.mkdir(mode=0o755)
        passwords={name:secrets.token_urlsafe(18) for name in SUBJECTS}
        (private/'users.json').write_text(json.dumps(passwords))
        config=realm(passwords);config['clients'][0]['redirectUris']=[CALLBACK]
        config['clients'][0]['attributes']['post.logout.redirect.uris']=ORIGIN+'/'
        (mount/'realm.json').write_text(json.dumps(config));(mount/'realm.json').chmod(0o644)
        tls=runtime/'browser-tls';tls.mkdir(mode=0o700,exist_ok=True)
        if not (tls/'cert.pem').exists():
            subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-keyout',str(tls/'key.pem'),'-out',str(tls/'cert.pem'),'-days','7','-subj','/CN=localhost','-addext','subjectAltName=DNS:localhost,IP:127.0.0.1'],capture_output=True,check=True,timeout=30)
        subprocess.run(['openssl','x509','-in',str(tls/'cert.pem'),'-checkend',str(int(args.hours*3600)),'-noout'],capture_output=True,check=True,timeout=10)
        for file in ('key.pem','cert.pem'):
            shutil.copyfile(tls/file,mount/file);(mount/file).chmod(0o644)
        state=dict(status='starting',pid=os.getpid(),process_identity=process_identity(os.getpid()),url=ORIGIN,private_directory=str(private),expires_at=(datetime.now(timezone.utc)+timedelta(hours=args.hours)).isoformat())
        def save():status_file.write_text(json.dumps(state,indent=2)+'\n')
        save();server=None;created=False
        def run(*cmd,required=True):
            result=subprocess.run(docker(runtime)+list(cmd),capture_output=True,text=True,timeout=300)
            if required and result.returncode:raise RuntimeError('Docker operation failed: '+result.stderr)
            return result
        def remove(kind,name):
            r=run(kind,'inspect',name,required=False)
            if r.returncode:
                if 'No such' not in r.stderr and 'not found' not in r.stderr:raise RuntimeError('Ownership lookup failed')
                return
            value=json.loads(r.stdout)[0];labels=value.get('Labels') if kind=='network' else value['Config'].get('Labels')
            if (labels or {}).get(LABEL)!='true':raise ValueError('Unrelated fixture collision')
            run(*(['rm','-f',name] if kind=='container' else ['network','rm',name]))
        try:
            remove('container',NAME);remove('network',NETWORK)
            if run('image','inspect',IMAGE,required=False).returncode:run('pull',IMAGE)
            run('network','create','--label',LABEL+'=true',NETWORK);created=True
            run('run','-d','--name',NAME,'--label',LABEL+'=true','--network',NETWORK,'--user','1000:1000','--cap-drop=ALL','--security-opt=no-new-privileges','--memory','640m','--memory-swap','640m','--cpus','1','--pids-limit','256','-e','JAVA_OPTS_KC_HEAP=-Xms64m -Xmx256m','--mount',f'type=bind,src={mount},dst=/lab,readonly','--mount',f'type=bind,src={mount}/realm.json,dst=/opt/keycloak/data/import/realm.json,readonly','-p','127.0.0.1:18446:8443',IMAGE,'start-dev','--import-realm','--hostname='+BASE,'--http-enabled=false','--https-certificate-file=/lab/cert.pem','--https-certificate-key-file=/lab/key.pem')
            context=ssl.create_default_context(cafile=str(tls/'ca.pem' if (tls/'ca.pem').exists() else mount/'cert.pem'))
            client=urllib.request.build_opener(urllib.request.ProxyHandler({}),urllib.request.HTTPSHandler(context=context))
            def keys():
                with client.open(ISSUER+'/protocol/openid-connect/certs',timeout=10) as response:return json.load(response)
            deadline=time.monotonic()+180
            while True:
                try:jwks=keys();break
                except OSError:
                    if time.monotonic()>deadline or stopping.is_set():raise TimeoutError('Provider readiness')
                    stopping.wait(1)
            replace_trust(runtime,jwks,trust_hours=args.hours)
            server=BrowserServer(str(mount/'cert.pem'),str(mount/'key.pem'),context,jwks).start()
            key_hash=hashlib.sha256(json.dumps(jwks,sort_keys=True).encode()).hexdigest()
            state.update(status='ready',public_jwks_sha256=key_hash);save();print('Browser lab ready at '+ORIGIN,flush=True)
            deadline=time.monotonic()+args.hours*3600
            while not stopping.wait(min(120,max(0,deadline-time.monotonic()))):
                if time.monotonic()>=deadline:break
                try:
                    refreshed=keys()
                    if hashlib.sha256(json.dumps(refreshed,sort_keys=True).encode()).hexdigest()!=key_hash:raise ValueError('Provider key drift; explicit restart required')
                    with server.store.lock:
                        server.access=TokenVerifier(refreshed);server.identity=TokenVerifier(refreshed,audience=CLIENT)
                    state['last_key_refresh']=datetime.now(timezone.utc).isoformat();save()
                except OSError:
                    state['last_key_refresh']='unavailable; existing snapshot expires fail-closed';save()
        except BaseException as error:
            state.update(status='failed',failure_type=type(error).__name__);raise
        finally:
            if server:server.close()
            if created:remove('container',NAME);remove('network',NETWORK)
            if state['status']!='failed':state['status']='stopped'
            state['finished_at']=datetime.now(timezone.utc).isoformat();save()

if __name__=='__main__':main()
