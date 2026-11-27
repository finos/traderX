"""Owned, loopback-only TLS JetStream fixture; persistent only for this campaign."""
from contextlib import contextmanager
import json
import os
from pathlib import Path
import secrets
import socket
import ssl
import subprocess
import tempfile
import time
import uuid
from portability import docker, isolated_linux
from verify_bootstrap import command

# Platform manifests are resolved from the immutable C3 parent index.
LOCK = Path(__file__).resolve().parents[2]/'specs/019-traderx-security-lab/system/jetstream-images.lock.json'


def image_for_arch(machine):
    arch={'aarch64':'arm64','arm64':'arm64','x86_64':'amd64','amd64':'amd64'}.get(machine)
    if not arch:raise ValueError('Unsupported broker daemon architecture')
    lock=json.loads(LOCK.read_text())
    return arch,lock['images'][arch]


STREAM = 'SECURITY_EVENTS'
ACCOUNTS = (22214,62654)
SUBJECTS = [f'/accounts/{account}/{kind}' for account in ACCOUNTS for kind in ('trades','positions')]


def broker_user():
    # Native Linux bind files keep container ownership. Use the unprivileged
    # dedicated runner UID so its private store can be removed after shutdown.
    if isolated_linux():
        uid,gid=os.getuid(),os.getgid()
        if uid<=0 or gid<=0:raise ValueError('Dedicated Linux runner must be unprivileged')
        return f'{uid}:{gid}'
    return '10001:10001'


def permissions():
    return {
      'bootstrap': {'publish':{'allow':['$JS.API.>']},'subscribe':{'allow':['_INBOX.bootstrap.>']}},
      'publisher': {'publish':{'allow':SUBJECTS},'subscribe':{'allow':['_INBOX.publisher.>']}},
      **{name:{'publish':{'allow':[f'$JS.API.CONSUMER.MSG.NEXT.{STREAM}.{durable}', f'$JS.ACK.{STREAM}.{durable}.>']},
               'subscribe':{'allow':[f'_INBOX.{name}.>']}}
         for name,durable in [('consumer-a','ACCOUNT_A'),('consumer-b','ACCOUNT_B')]}}


def fixture_permissions(extra=None):
    import re
    rules=permissions()
    if extra:
        for identity,policy in extra.items():
            if identity in rules or not re.fullmatch(r'[a-z][a-z0-9_-]{0,40}',identity):
                raise ValueError('Duplicate or invalid fixture identity')
            if not isinstance(policy,dict) or set(policy)!={'publish','subscribe'}:
                raise ValueError('Explicit fixture publish/subscribe policy required')
            for value in policy.values():
                if not isinstance(value,dict) or not value or not set(value)<={'allow','deny'}:
                    raise ValueError('Explicit fixture subject policy required')
                if any(not isinstance(subjects,list) or any(not isinstance(x,str) or not x or len(x)>160 for x in subjects) for subjects in value.values()):
                    raise ValueError('Invalid fixture subject policy')
                if not any(value.values()):
                    raise ValueError('Empty NATS lists are not a deny-all policy')
            rules[identity]=policy
    return rules


@contextmanager
def broker(runtime, extra_permissions=None):
    cli=docker(runtime);run_id=uuid.uuid4().hex;name='traderx-events-'+run_id[:12]
    arch,image=image_for_arch(command(cli+['info','--format','{{.Architecture}}']))
    user=broker_user()
    label='traderx.security-lab.events';attempted=False
    with tempfile.TemporaryDirectory(prefix='events-private-',dir=runtime) as temp:
        private=Path(temp);config_dir=private/'config';data_dir=private/'data'
        config_dir.mkdir(mode=0o755);config_dir.chmod(0o755)
        data_dir.mkdir(mode=0o777);data_dir.chmod(0o777)
        rules=fixture_permissions(extra_permissions)
        passwords={name:secrets.token_hex(24) for name in rules}
        certificate=config_dir/'cert.pem';key=config_dir/'key.pem'
        subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-keyout',str(key),'-out',str(certificate),
          '-days','1','-subj','/CN=localhost','-addext','subjectAltName=DNS:localhost,IP:127.0.0.1'],capture_output=True,check=True,timeout=30)
        key.chmod(0o644);certificate.chmod(0o644)
        config={'port':4222,'max_payload':8192,'max_connections':16,
          'jetstream':{'store_dir':'/store','max_memory_store':8388608,'max_file_store':16777216},
          'tls':{'cert_file':'/lab/cert.pem','key_file':'/lab/key.pem','handshake_first':True,'timeout':3},
          'authorization':{'users':[{'user':user,'password':passwords[user],'permissions':policy} for user,policy in rules.items()]}}
        (config_dir/'nats.json').write_text(json.dumps(config));(config_dir/'nats.json').chmod(0o644)
        def owned():
            value=command(cli+['inspect','--format','{{index .Config.Labels "'+label+'"}}',name])
            if value!=run_id:raise ValueError('Broker ownership mismatch')
        def ready():
            owned()
            state=json.loads(command(cli+['inspect','--format','{{json .State}}',name]))
            if not state.get('Running'):
                logs=subprocess.run(cli+['logs','--tail','20',name],capture_output=True,text=True,timeout=10)
                category='permission-denied' if 'permission denied' in (logs.stdout+logs.stderr).lower() else 'unclassified'
                raise RuntimeError('Broker stopped before readiness; exit code '+str(state.get('ExitCode'))+'; category '+category)
            endpoint=command(cli+['port',name,'4222/tcp'])
            if not endpoint.startswith('127.0.0.1:') or not endpoint.split(':')[1].isdigit():raise ValueError('Broker publication mismatch')
            port=int(endpoint.split(':')[1]);context=ssl.create_default_context(cafile=str(certificate))
            deadline=time.monotonic()+30
            while True:
                try:
                    with socket.create_connection(('127.0.0.1',port),timeout=1) as sock:
                        with context.wrap_socket(sock,server_hostname='localhost') as tls:
                            if not tls.recv(4096).startswith(b'INFO '):raise ValueError('Missing broker INFO')
                    return f'tls://localhost:{port}'
                except OSError:
                    if time.monotonic()>=deadline:raise TimeoutError('Broker readiness timeout')
                    time.sleep(.1)
        def restart():
            owned();command(cli+['restart','--time','10',name]);return ready()
        try:
            if subprocess.run(cli+['image','inspect',image],capture_output=True).returncode:
                command(cli+['pull','--platform','linux/'+arch,image],timeout=180)
            # Docker may reallocate an ephemeral publication after restart. Reserve
            # an explicit loopback endpoint so reconnect exercises the same address.
            # A competing bind fails create safely; no unrelated listener is reused.
            with socket.socket() as probe:
                probe.bind(('127.0.0.1',0));published_port=probe.getsockname()[1]
            attempted=True
            command(cli+['create','--name',name,'--label',label+'='+run_id,'--restart','no',
              '--platform','linux/'+arch,'--read-only','--user',user,'--cap-drop','ALL','--security-opt','no-new-privileges:true',
              '--memory','128m','--memory-swap','128m','--cpus','0.5','--pids-limit','64',
              '--log-driver','local','--log-opt','max-size=2m','--log-opt','max-file=2',
              '--mount',f'type=bind,src={config_dir},dst=/lab,readonly',
              '--mount',f'type=bind,src={data_dir},dst=/store','--publish',f'127.0.0.1:{published_port}:4222',image,'-c','/lab/nats.json'])
            command(cli+['start',name]);endpoint=ready()
            info=json.loads(command(cli+['inspect',name]))[0]
            host=info['HostConfig']
            if not host['ReadonlyRootfs'] or host['CapDrop']!=['ALL'] or info['Config']['User']!=user:raise ValueError('Broker restrictions missing')
            if set(host['PortBindings'])!={'4222/tcp'} or any(p['HostIp']!='127.0.0.1' for p in host['PortBindings']['4222/tcp']):raise ValueError('Broker exposure mismatch')
            yield {'image':image,'architecture':arch,'runtime_user':user,'endpoint':endpoint,'ca':certificate,'passwords':passwords,'restart':restart}
        finally:
            if attempted:
                found=command(cli+['ps','-aq','--filter','name=^/'+name+'$','--filter','label='+label+'='+run_id]).split()
                if len(found)>1:raise ValueError('Ambiguous broker ownership')
                if found:command(cli+['rm','-f',found[0]])
