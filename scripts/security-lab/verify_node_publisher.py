"""Exercise the real canonical Node publisher against the isolated authenticated broker."""
import json
import hashlib
import os
from pathlib import Path
import socket
import subprocess
import time
import urllib.request
from nats_fixture import Client


def verify(directory, context, cert, passwords, private):
    directory=Path(directory).resolve()
    if not (directory/'src/main.js').is_file() or not (directory/'node_modules/nats').is_dir():
        raise ValueError('Prepared publisher source and locked dependencies required')
    canonical=Path(__file__).resolve().parents[2]/'templates/state-010-pricing-awareness-market-data-overlay/price-publisher'
    hashes={}
    for name in ['src/main.js','src/nats-options.js','package-lock.json']:
        actual=(directory/name).read_bytes()
        if actual!=(canonical/name).read_bytes():raise ValueError('Prepared publisher differs from canonical source: '+name)
        hashes[name]=hashlib.sha256(actual).hexdigest()
    observer=Client('tcp',context,cert)
    observer.connect('observer',passwords['observer']);observer.subscribe('pricing.AAPL')
    try:
        for filename,value in [('user','pricer'),('password',passwords['pricer'])]:
            path=private/filename;path.write_text(value);path.chmod(0o600)
        with socket.socket() as probe:
            probe.bind(('127.0.0.1',0));port=probe.getsockname()[1]
        env={k:v for k,v in os.environ.items() if not k.startswith(('NATS_','PRICE_','PUBLISH_'))}
        env.update(NATS_SECURITY_REQUIRED='true',NATS_ADDRESS='tls://localhost:18444',NATS_USER_FILE=str(private/'user'),NATS_PASSWORD_FILE=str(private/'password'),NATS_CA_FILE=str(cert),PRICE_PUBLISHER_PORT=str(port),PRICE_BOOTSTRAP_MODE='snapshot',PRICE_TICKERS='AAPL',PUBLISH_INTERVAL_MIN_MS='100',PUBLISH_INTERVAL_MAX_MS='100')
        with tempfile_log(private) as log:
            child=subprocess.Popen(['node',str(directory/'src/main.js')],env=env,stdout=log,stderr=log)
            try:
                deadline=time.monotonic()+20
                while time.monotonic()<deadline:
                    if child.poll() is not None:raise RuntimeError('Secure publisher exited before readiness; private log retained only during fixture')
                    try:
                        with urllib.request.urlopen(f'http://127.0.0.1:{port}/health',timeout=1) as r:health=json.load(r)
                        if health['status']=='ok':break
                    except OSError:pass
                    time.sleep(.1)
                else:raise TimeoutError('Secure publisher readiness not verified')
                while time.monotonic()<deadline:
                    observer.flush()
                    if observer.messages:break
                    time.sleep(.1)
                assert observer.messages,'No price reached the authorized observer'
                payload=json.loads(observer.messages[-1]['payload'])
                assert payload.get('ticker')=='AAPL' or payload.get('payload',{}).get('ticker')=='AAPL'
                result={'status':'passed','health':'ok','subject':'pricing.AAPL','observer_received':True,'tls_first':True,'identity':'pricer'}
            finally:
                if child.poll() is None:child.terminate()
                try:child.wait(timeout=5)
                except subprocess.TimeoutExpired:child.kill();child.wait(timeout=5)
        wrong=private/'wrong-password';wrong.write_text('wrong-synthetic-password');wrong.chmod(0o600)
        subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-keyout',str(private/'other-key.pem'),'-out',str(private/'other-ca.pem'),'-days','1','-subj','/CN=untrusted-fixture'],capture_output=True,check=True,timeout=30)
        for case,override in [('invalid-password',{'NATS_PASSWORD_FILE':str(wrong)}),('untrusted-ca',{'NATS_CA_FILE':str(private/'other-ca.pem')})]:
            attempt=subprocess.run(['node',str(directory/'src/main.js')],env=env|override,capture_output=True,text=True,timeout=20)
            assert attempt.returncode != 0 and 'Secure price publisher startup failed' in attempt.stderr, 'Invalid connection was not explicitly rejected'
            assert passwords['pricer'] not in attempt.stdout+attempt.stderr
            result[case]='startup-rejected'
        result['source_hashes']=hashes
        result['nats_client_version']=json.loads((directory/'node_modules/nats/package.json').read_text())['version']
        return result
    finally:observer.close()


def tempfile_log(private):
    path=private/'publisher.log'
    path.touch(mode=0o600)
    return path.open('w')
