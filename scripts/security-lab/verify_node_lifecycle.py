"""Isolated real publisher reconnect and password-rotation lifecycle."""
import json
import os
from pathlib import Path
import socket
import subprocess
import time
import urllib.request
from nats_fixture import Client


def verify(directory, context, cert, passwords, private, restart):
    old_password=passwords['pricer']
    user_file=private/'lifecycle-user';password_file=private/'lifecycle-password'
    for path,value in [(user_file,'pricer'),(password_file,old_password)]:path.write_text(value);path.chmod(0o600)
    with socket.socket() as probe:probe.bind(('127.0.0.1',0));port=probe.getsockname()[1]
    env={k:v for k,v in os.environ.items() if not k.startswith(('NATS_','PRICE_','PUBLISH_'))}
    env.update(NATS_SECURITY_REQUIRED='true',NATS_ADDRESS='tls://localhost:18444',NATS_USER_FILE=str(user_file),NATS_PASSWORD_FILE=str(password_file),NATS_CA_FILE=str(cert),PRICE_PUBLISHER_PORT=str(port),PRICE_BOOTSTRAP_MODE='snapshot',PRICE_TICKERS='AAPL',PUBLISH_INTERVAL_MIN_MS='100',PUBLISH_INTERVAL_MAX_MS='100')
    log_file=private/'lifecycle.log';log_file.touch(mode=0o600)
    child=None
    def stop():
        if child is not None:
            if child.poll() is None:child.terminate()
            try:child.wait(timeout=5)
            except subprocess.TimeoutExpired:child.kill();child.wait(timeout=5)
    def observe():
        observer=Client('tcp',context,cert)
        try:
            observer.connect('observer',passwords['observer']);observer.subscribe('pricing.AAPL')
            started=time.time();deadline=time.monotonic()+20
            while time.monotonic()<deadline:
                if child.poll() is not None:raise RuntimeError('Publisher exited during permitted reconnect')
                observer.flush()
                fresh=[json.loads(m['payload']) for m in observer.messages]
                for message in fresh:
                    from datetime import datetime
                    stamp=datetime.fromisoformat(message['payload']['asOf'].replace('Z','+00:00')).timestamp()
                    if stamp>=started and message['payload']['ticker']=='AAPL':return
                time.sleep(.1)
            raise TimeoutError('No fresh price after broker recovery')
        finally:observer.close()
    try:
        with log_file.open('a') as log:
            child=subprocess.Popen(['node',str(Path(directory)/'src/main.js')],env=env,stdout=log,stderr=log)
            observe();initial_pid=child.pid
            restart(False);observe()
            assert child.pid==initial_pid and child.poll() is None
            restart(True)
            retired=Client('tcp',context,cert)
            try:
                try:retired.connect('pricer',old_password)
                except (PermissionError,ConnectionError):pass
                assert any('Authorization Violation' in error for error in retired.errors)
            finally:retired.close()
            password_file.write_text(passwords['pricer'])
            # Credential files are startup inputs; explicitly replace the old process.
            stop()
            child=subprocess.Popen(['node',str(Path(directory)/'src/main.js')],env=env,stdout=log,stderr=log)
            observe();assert child.pid!=initial_pid
            with urllib.request.urlopen(f'http://127.0.0.1:{port}/health',timeout=3) as response:assert json.load(response)['status']=='ok'
            return {'status':'passed','unchanged_credentials_reconnect':'fresh-price-same-process','retired_fresh_login':'explicit-authentication-denial','rotation':'fresh-price-after-file-update-and-process-replacement','health_after_rotation':'ok','limitations':['Broker restart deliberately closes all sessions; does not test password reload effects on established sessions.','Price stream delivery during broker outage is not guaranteed; fresh timestamps are verified after recovery.','No claim of credential hot reload or Spring service lifecycle coverage.']}
    finally:stop()
