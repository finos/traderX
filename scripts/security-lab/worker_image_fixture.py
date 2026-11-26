"""Hosted-only owned TLS PostgreSQL/NATS peers for inspected worker images."""
from contextlib import contextmanager
import datetime
import ipaddress
import json
import os
from pathlib import Path
import secrets
import socket
import ssl
import subprocess
import tempfile
import time

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import ExtendedKeyUsageOID, NameOID

import bootstrap_database
from jetstream_fixture import image_for_arch, permissions, STREAM
import portability
from verify_bootstrap import require
from verify_runtime_images import Docker

LABEL='traderx.security-lab.worker-peers'
ACK_PROBE=f'$JS.ACK.{STREAM}.ACCOUNT_A.0.0.0.0.0'
STAGES=frozenset(('guard','pins','pull_database','pull_broker','private_directory','network_plan','certificates',
    'database_files','broker_files','network_create','network_verify','volume_create','database_create','broker_create',
    'database_start','broker_start','database_ready','broker_ready','bootstrap','active','cleanup','private_cleanup'))
ERROR_TYPES=frozenset(('ValueError','RuntimeError','OSError','PermissionError','FileNotFoundError','TimeoutError',
    'SubprocessError','KeyError','TypeError','JSONDecodeError','other'))


class FixtureFailure(RuntimeError):
    def __init__(self,details):
        self.details=details
        super().__init__('Owned TLS peer readiness failed; private details withheld')


def setup_failure(stage,error):
    kind=type(error).__name__
    details={'peer':'unknown','category':'unclassified','running':None,'exit_code':None,'oom_killed':None,
             'stage':stage if stage in STAGES else 'guard','error_type':kind if kind in ERROR_TYPES else 'other'}
    return FixtureFailure(details)


@contextmanager
def private_directory(runtime):
    directory=tempfile.TemporaryDirectory(prefix='worker-peers-private-',dir=runtime)
    try:yield directory.name
    finally:
        try:directory.cleanup()
        except Exception as error:raise setup_failure('private_cleanup',error) from None


def readiness_failure(docker,name,peer):
    result={'peer':peer if peer in ('database','broker') else 'unknown','category':'unclassified',
            'running':None,'exit_code':None,'oom_killed':None}
    try:
        state=json.loads(docker('container','inspect',name).stdout)[0]['State']
        for key,field in (('running','Running'),('oom_killed','OOMKilled')):
            if type(state.get(field)) is bool:result[key]=state[field]
        code=state.get('ExitCode')
        if type(code) is int and 0<=code<=255:result['exit_code']=code
        logs=docker('logs','--tail','20',name,check=False)
        text=(logs.stdout+logs.stderr).lower()
        for marker,category in (('no space left','storage_capacity'),('read-only file system','readonly_filesystem'),
                ('private key file','tls_private_key'),('permission denied','permissions'),
                ('password authentication failed','authentication'),('certificate','tls_configuration'),
                ('configuration file','configuration')):
            if marker in text:result['category']=category;break
        if result['oom_killed']:result['category']='memory_limit'
    except Exception:pass
    return FixtureFailure(result)


def tls_material(addresses):
    """Common ephemeral CA; leaves cover only actual peer alias/IP, never negatives."""
    now=datetime.datetime.now(datetime.timezone.utc)
    ca_key=rsa.generate_private_key(public_exponent=65537,key_size=2048)
    issuer=x509.Name([x509.NameAttribute(NameOID.COMMON_NAME,'Synthetic worker image CA')])
    ca=(x509.CertificateBuilder().subject_name(issuer).issuer_name(issuer).public_key(ca_key.public_key())
        .serial_number(x509.random_serial_number()).not_valid_before(now-datetime.timedelta(minutes=1))
        .not_valid_after(now+datetime.timedelta(hours=2))
        .add_extension(x509.BasicConstraints(ca=True,path_length=0),critical=True)
        .add_extension(x509.KeyUsage(False,False,False,False,False,True,True,None,None),critical=True)
        .add_extension(x509.SubjectKeyIdentifier.from_public_key(ca_key.public_key()),critical=False)
        .add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(ca_key.public_key()),critical=False)
        .sign(ca_key,hashes.SHA256()))
    result={'ca.pem':ca.public_bytes(serialization.Encoding.PEM)}
    for name,address in addresses.items():
        if name not in ('database','nats-broker'):raise ValueError('Unreviewed TLS peer alias')
        ip=ipaddress.IPv4Address(address)
        key=rsa.generate_private_key(public_exponent=65537,key_size=2048)
        leaf=(x509.CertificateBuilder().subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME,name)]))
            .issuer_name(issuer).public_key(key.public_key()).serial_number(x509.random_serial_number())
            .not_valid_before(now-datetime.timedelta(minutes=1)).not_valid_after(now+datetime.timedelta(hours=2))
            .add_extension(x509.BasicConstraints(ca=False,path_length=None),critical=True)
            .add_extension(x509.SubjectAlternativeName([x509.DNSName(name),x509.IPAddress(ip)]),critical=False)
            .add_extension(x509.KeyUsage(True,False,True,False,False,False,False,None,None),critical=True)
            .add_extension(x509.SubjectKeyIdentifier.from_public_key(key.public_key()),critical=False)
            .add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(ca_key.public_key()),critical=False)
            .add_extension(x509.ExtendedKeyUsage([ExtendedKeyUsageOID.SERVER_AUTH]),critical=False)
            .sign(ca_key,hashes.SHA256()))
        result[name]={'cert.pem':leaf.public_bytes(serialization.Encoding.PEM),
                    'key.pem':key.private_bytes(serialization.Encoding.PEM,serialization.PrivateFormat.PKCS8,serialization.NoEncryption())}
    return result


def choose_subnet(existing,host_routes):
    occupied=[]
    for value in existing:
        ipam=value.get('IPAM',{})
        if not isinstance(ipam,dict):raise ValueError('Invalid Docker IPAM metadata')
        config=ipam.get('Config')
        # Docker host/none networks legitimately have no IPAM configuration.
        # An explicit JSON null and an omitted field both mean no subnets.
        if config is None:config=[]
        if not isinstance(config,list) or any(not isinstance(entry,dict) for entry in config):
            raise ValueError('Invalid Docker IPAM subnet inventory')
        for entry in config:
            if entry.get('Subnet'):occupied.append(ipaddress.ip_network(entry['Subnet']))
    for route in host_routes:
        destination=route.get('dst')
        if destination and destination!='default':occupied.append(ipaddress.ip_network(destination,strict=False))
    for prefix in ('172.28','10.248'):
        for third in range(240,256):
            candidate=ipaddress.IPv4Network(f'{prefix}.{third}.0/24')
            if not any(value.version==4 and candidate.overlaps(value) for value in occupied):return candidate
    raise ValueError('No unoccupied bounded fixture subnet')


def network_plan(docker):
    ids=docker('network','ls','-q').stdout.split()
    if len(ids)>64:raise ValueError('Unexpected network inventory size')
    existing=json.loads(docker('network','inspect',*ids).stdout) if ids else []
    result=subprocess.run(['ip','-json','-4','route','show'],capture_output=True,text=True,timeout=10)
    if result.returncode or len(result.stdout)>65536:raise RuntimeError('Host route inventory unavailable')
    return choose_subnet(existing,json.loads(result.stdout))


def owned(docker,kind,name,owner,missing=False):
    result=docker(kind,'inspect',name,check=False)
    if result.returncode:
        # Inspect errors are not proof of absence: list names independently.
        command=('ps','-a','--format','{{.Names}}') if kind=='container' else (kind,'ls','--format','{{.Name}}')
        if name in docker(*command).stdout.splitlines() or not missing:
            raise RuntimeError('Owned peer inspection unavailable')
        return None
    data=json.loads(result.stdout)
    if len(data)!=1:raise ValueError('Ambiguous peer ownership')
    value=data[0]
    labels=value.get('Config',{}).get('Labels',{}) if kind=='container' else value.get('Labels',{})
    if labels.get(LABEL)!=owner:raise ValueError('Peer ownership mismatch')
    actual=value.get('Name','').lstrip('/')
    if actual!=name:raise ValueError('Peer resource name mismatch')
    return value


def cleanup(docker,containers,volume,network,owner):
    failed=False
    resources=[('container',name) for name in reversed(containers)]
    if volume:resources.append(('volume',volume))
    if network:resources.append(('network',network))
    for kind,name in resources:
        try:
            if owned(docker,kind,name,owner,missing=True) is None:continue
            if kind=='container':docker('rm','-f',name)
            else:docker(kind,'rm',name)
            if owned(docker,kind,name,owner,missing=True) is not None:raise RuntimeError('Peer remains after cleanup')
        except Exception:failed=True
    if failed:raise RuntimeError('Owned worker peer cleanup incomplete; private details withheld')


def private_files(directory,values,gid):
    directory.mkdir(mode=0o750);directory.chmod(0o750)
    for name,data in values.items():
        path=directory/name;path.write_bytes(data);path.chmod(0o640 if name=='key.pem' else 0o440)
    for args in (['sudo','-n','chgrp',str(gid),str(directory)],
                 ['sudo','-n','chown','0:'+str(gid),*[str(directory/name) for name in sorted(values)]]):
        result=subprocess.run(args,capture_output=True,timeout=10)
        if result.returncode:raise RuntimeError('Private peer file ownership unavailable')


def peer_config(passwords,ack_allowed=True):
    if type(ack_allowed) is not bool:raise ValueError('Explicit ACK permission required')
    rules=permissions()
    if not ack_allowed:
        rules['consumer-a']['publish']['allow']=[value for value in rules['consumer-a']['publish']['allow'] if not value.startswith('$JS.ACK.')]
    return {'port':4222,'max_payload':8192,'max_connections':16,
        'jetstream':{'store_dir':'/store','max_memory_store':8388608,'max_file_store':16777216},
        'tls':{'cert_file':'/lab/cert.pem','key_file':'/lab/key.pem','handshake_first':True,'timeout':3},
        'authorization':{'users':[{'user':name,'password':passwords[name],'permissions':rule} for name,rule in rules.items()]}}


def postgres_args(name,network,owner,address,image,config,volume):
    return ['create','--name',name,'--label',LABEL+'='+owner,'--network',network,
        '--network-alias','database','--network-alias','wrong-database','--ip',address,
        '--platform','linux/amd64','--restart','no','--user','70:70','--read-only',
        '--cap-drop','ALL','--security-opt','no-new-privileges:true','--memory','256m','--memory-swap','256m',
        '--cpus','1','--pids-limit','128','--log-driver','local','--log-opt','max-size=2m','--log-opt','max-file=2',
        '--mount',f'type=bind,src={config},dst=/lab,readonly',
        '--mount',f'type=volume,src={volume},dst=/var/lib/postgresql/data',
        '--tmpfs','/var/run/postgresql:uid=70,gid=70,mode=0770,size=1048576',
        '--tmpfs','/tmp:uid=70,gid=70,mode=0700,size=16777216',
        '--tmpfs','/docker-entrypoint-initdb.d:uid=70,gid=70,mode=0755,size=1048576',
        '-e','POSTGRES_DB=traderx','-e','POSTGRES_USER=traderx','-e','POSTGRES_PASSWORD_FILE=/lab/password',
        '-e','POSTGRES_INITDB_ARGS=--auth-host=scram-sha-256',image,'postgres',
        '-c','listen_addresses=0.0.0.0','-c','ssl=on','-c','ssl_min_protocol_version=TLSv1.2',
        '-c','ssl_cert_file=/lab/cert.pem','-c','ssl_key_file=/lab/key.pem','-c','hba_file=/lab/pg_hba.conf',
        '-c','max_wal_size=32MB','-c','min_wal_size=32MB','-c','log_statement=none','-c','log_min_error_statement=panic']


def nats_args(name,network,owner,address,image,config,store,user):
    return ['create','--name',name,'--label',LABEL+'='+owner,'--network',network,
        '--network-alias','nats-broker','--network-alias','wrong-broker','--ip',address,
        '--platform','linux/amd64','--restart','no','--user',user,'--read-only',
        '--cap-drop','ALL','--security-opt','no-new-privileges:true','--memory','128m','--memory-swap','128m',
        '--cpus','0.5','--pids-limit','64','--log-driver','local','--log-opt','max-size=2m','--log-opt','max-file=2',
        '--mount',f'type=bind,src={config},dst=/lab,readonly','--mount',f'type=bind,src={store},dst=/store',image,'-c','/lab/nats.json']


def permission_probe(address,ca,password):
    """Return actual publish decision for a nonexistent sequence, never an effect."""
    context=ssl.create_default_context(cafile=ca)
    with socket.create_connection((address,4222),timeout=3) as raw:
        with context.wrap_socket(raw,server_hostname=address) as connection:
            stream=connection.makefile('rb');budget=4096
            def line():
                nonlocal budget
                value=stream.readline(min(1024,budget)+1);budget-=len(value)
                if not value.endswith(b'\r\n') or budget<0:raise ValueError('Bounded broker protocol required')
                return value
            if not line().startswith(b'INFO '):raise ValueError('Broker INFO unavailable')
            connect=json.dumps({'user':'consumer-a','pass':password,'verbose':True,'pedantic':True,'lang':'python','version':'fixture','protocol':1}).encode()
            connection.sendall(b'CONNECT '+connect+b'\r\nPING\r\n')
            while True:
                value=line()
                if value==b'PONG\r\n':break
                if value!=b'+OK\r\n':raise ValueError('Broker permission probe authentication unavailable')
            connection.sendall(b'PUB '+ACK_PROBE.encode()+b' 4\r\n+ACK\r\nPING\r\n')
            accepted=denied=False
            while True:
                value=line()
                if value==b'PONG\r\n':break
                if value==b'+OK\r\n':accepted=True
                elif value.startswith(b'-ERR ') and b'Permissions Violation for Publish' in value:denied=True
                else:raise ValueError('Unexpected broker permission response')
            if accepted==denied:raise ValueError('Ambiguous broker permission decision')
            return accepted


def broker_info(connection):
    # TLS preserves a byte stream, not NATS message boundaries. A single recv
    # may legally return only the first byte of INFO; read one bounded line.
    with connection.makefile('rb') as stream:value=stream.readline(4097)
    if len(value)>4096 or not value.startswith(b'INFO ') or not value.endswith(b'\r\n'):
        raise ValueError('Bounded broker INFO unavailable')


@contextmanager
def _fixture(runtime,progress):
    if not portability.isolated_linux() or os.environ.get('GITHUB_ACTIONS')!='true' or os.getuid()<=0 or os.getgid()<=0:
        raise ValueError('Worker peers require unprivileged isolated hosted Linux')
    runtime=Path(runtime).resolve();docker=Docker(runtime);owner=secrets.token_hex(12)
    network='traderx-worker-peers-'+owner;volume=network+'-pgdata'
    containers=[];network_attempted=volume_attempted=False
    progress['stage']='pins'
    reference=bootstrap_database.pinned_reference();identities=bootstrap_database.credentials()
    database_image=next(value for value in reference['items'] if value['kind']=='Deployment' and value['metadata']['name']=='database')['spec']['template']['spec']['containers'][0]['image']
    _,broker_image=image_for_arch('amd64')
    for peer,image in (('database',database_image),('broker',broker_image)):
        progress['stage']='pull_'+peer
        if '@sha256:' not in image:raise ValueError('Pinned peer image required')
        if docker('image','inspect',image,check=False).returncode:docker('pull','--platform','linux/amd64',image,timeout=240)
    progress['stage']='private_directory'
    with private_directory(runtime) as temporary:
        private=Path(temporary);progress['stage']='network_plan';subnet=network_plan(docker)
        gateway=str(subnet.network_address+1);addresses={'database':str(subnet.network_address+2),'nats-broker':str(subnet.network_address+3)}
        progress['stage']='certificates'
        material=tls_material(addresses);ca=private/'ca.pem';ca.write_bytes(material['ca.pem']);ca.chmod(0o600)
        passwords={name:secrets.token_hex(24) for name in permissions()};password=secrets.token_hex(32)
        database_config=private/'database';broker_config=private/'broker';store=private/'store';store.mkdir(mode=0o700)
        hba=('local all all trust\nhostnossl all all 0.0.0.0/0 reject\nhostssl all all '+str(subnet)+' scram-sha-256\nhost all all 0.0.0.0/0 reject\n')
        progress['stage']='database_files'
        private_files(database_config,{**material['database'],'ca.pem':material['ca.pem'],'password':password.encode(),
                                     'pg_hba.conf':hba.encode()},70)
        progress['stage']='broker_files'
        private_files(broker_config,{**material['nats-broker'],'nats.json':json.dumps(peer_config(passwords)).encode()},os.getgid())
        db_name=network+'-database';broker_name=network+'-broker'
        def inspected(name,address):
            value=owned(docker,'container',name,owner)
            config=value['HostConfig']
            if (not value['State'].get('Running') or value['NetworkSettings']['Networks'][network]['IPAddress']!=address
                    or config.get('PortBindings') or not config.get('ReadonlyRootfs') or config.get('CapDrop')!=['ALL']):
                raise RuntimeError('TLS peer runtime boundary unavailable')
            return value
        def sql(role,credential,query):
            # Password and SQL travel only through stdin. The shell command is
            # fixed, and role is a distinct argv token, never shell-expanded code.
            shell='IFS= read -r PGPASSWORD; export PGPASSWORD; export PGCONNECT_TIMEOUT=3 PGSSLMODE=verify-full PGSSLROOTCERT=/lab/ca.pem; exec psql -X -w -h database -U "$1" -d traderx -At -v ON_ERROR_STOP=1 -v VERBOSITY=sqlstate'
            result=subprocess.run(docker.argv+['exec','-i',db_name,'sh','-c',shell,'fixture-sql',role],
                input=credential+'\n'+query+'\n',capture_output=True,text=True,timeout=45)
            if len(result.stdout)>65536 or len(result.stderr)>65536:raise RuntimeError('Fixture SQL output exceeded bound')
            return result
        def admin(query):return require(sql('traderx',password,query),'TLS fixture SQL failed')
        def database_ready():
            deadline=time.monotonic()+90
            while time.monotonic()<deadline:
                if not owned(docker,'container',db_name,owner)['State'].get('Running'):
                    raise readiness_failure(docker,db_name,'database')
                result=sql('traderx',password,'SELECT ssl FROM pg_stat_ssl WHERE pid=pg_backend_pid();')
                if result.returncode==0 and result.stdout.strip()=='t':
                    inspected(db_name,addresses['database']);return
                time.sleep(.25)
            raise readiness_failure(docker,db_name,'database')
        def broker_ready():
            deadline=time.monotonic()+30
            while time.monotonic()<deadline:
                if not owned(docker,'container',broker_name,owner)['State'].get('Running'):
                    raise readiness_failure(docker,broker_name,'broker')
                try:
                    context=ssl.create_default_context(cafile=ca)
                    with socket.create_connection((addresses['nats-broker'],4222),timeout=1) as raw:
                        with context.wrap_socket(raw,server_hostname=addresses['nats-broker']) as connection:
                            broker_info(connection)
                    inspected(broker_name,addresses['nats-broker']);return
                except OSError:time.sleep(.1)
                except ValueError:raise readiness_failure(docker,broker_name,'broker') from None
            raise readiness_failure(docker,broker_name,'broker')
        def restart_database():
            owned(docker,'container',db_name,owner);docker('restart','--time','10',db_name,timeout=30);database_ready()
        def restart_broker():
            owned(docker,'container',broker_name,owner);docker('restart','--time','10',broker_name,timeout=30);broker_ready()
        def set_consumer_ack_allowed(allowed):
            config=peer_config(passwords,allowed);owned(docker,'container',broker_name,owner)
            pending=broker_config/'nats.pending';pending.write_text(json.dumps(config));pending.chmod(0o440)
            result=subprocess.run(['sudo','-n','chown','0:'+str(os.getgid()),str(pending)],capture_output=True,timeout=10)
            if result.returncode:raise RuntimeError('Broker policy file ownership unavailable')
            os.replace(pending,broker_config/'nats.json')
            docker('exec',broker_name,'nats-server','-t','-c','/lab/nats.json')
            docker('kill','--signal=HUP',broker_name)
            deadline=time.monotonic()+10
            while time.monotonic()<deadline:
                try:
                    if permission_probe(addresses['nats-broker'],ca,passwords['consumer-a'])==allowed:return
                except OSError:pass
                time.sleep(.1)
            raise RuntimeError('Broker ACK permission change unverified')
        try:
            progress['stage']='network_create'
            network_attempted=True
            docker('network','create','--internal','--subnet',str(subnet),'--gateway',gateway,'--label',LABEL+'='+owner,network)
            progress['stage']='network_verify'
            info=owned(docker,'network',network,owner)
            if info.get('Internal') is not True or info['IPAM']['Config']!=[{'Subnet':str(subnet),'Gateway':gateway}]:
                raise RuntimeError('Owned internal network not established')
            progress['stage']='volume_create';volume_attempted=True;docker('volume','create','--label',LABEL+'='+owner,volume)
            progress['stage']='database_create'
            containers.append(db_name);docker(*postgres_args(db_name,network,owner,addresses['database'],database_image,database_config,volume))
            progress['stage']='broker_create'
            containers.append(broker_name);docker(*nats_args(broker_name,network,owner,addresses['nats-broker'],broker_image,broker_config,store,f'{os.getuid()}:{os.getgid()}'))
            progress['stage']='database_start';docker('start',db_name)
            progress['stage']='broker_start';docker('start',broker_name)
            progress['stage']='database_ready';database_ready()
            progress['stage']='broker_ready';broker_ready()
            progress['stage']='bootstrap';admin(bootstrap_database.render(reference,identities))
            progress['stage']='active'
            yield {'network':network,'owner':owner,'docker':docker,'private':private,'ca':ca,
                'database':{'host':'database','hostaddr':addresses['database'],'port':5432,'name':'traderx','ca':ca,'password':password,'image':database_image},
                'broker':{'endpoint':'tls://nats-broker:4222','host_endpoint':'tls://'+addresses['nats-broker']+':4222',
                          'ca':ca,'passwords':passwords,'image':broker_image},
                'sql':sql,'admin':admin,'database_password':password,'identities':identities,
                'restart_database':restart_database,'restart_broker':restart_broker,'set_consumer_ack_allowed':set_consumer_ack_allowed}
        finally:
            try:cleanup(docker,containers,volume if volume_attempted else None,network if network_attempted else None,owner)
            except Exception as error:raise setup_failure('cleanup',error) from None


@contextmanager
def fixture(runtime):
    progress={'stage':'guard'}
    try:
        with _fixture(runtime,progress) as value:yield value
    except FixtureFailure as error:
        error.details.setdefault('stage',progress['stage'])
        error.details.setdefault('error_type','RuntimeError')
        raise
    except Exception as error:
        # An exception in the caller's business campaign is its own evidence,
        # not a setup failure. Cleanup failures have already been wrapped above.
        if progress['stage']=='active':raise
        raise setup_failure(progress['stage'],error) from None
