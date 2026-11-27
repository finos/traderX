"""Hosted smoke of inspected Python OCI images; no business delivery claim."""
import argparse
from contextlib import contextmanager
import datetime
import http.client
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import ipaddress
import json
import os
from pathlib import Path
import re
import secrets
import signal
import socket
import ssl
import subprocess
import tempfile
import threading
import time

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import NameOID, ExtendedKeyUsageOID
import jwt

import integrated_deployment as compiler
import portability
import runtime_images
from runtime_launcher import BACKENDS

ROLES=('browser-session','event-publisher','event-consumer')
REFUSAL='Packaged runtime configuration refused; private details withheld.'
LABEL='traderx.security-lab.image-smoke'
STAGES=frozenset(('configuration','verify_images','network','issuer','browser_start','browser_ready',
    'browser_assets','browser_boundaries','worker_event_publisher','worker_event_consumer','cleanup','evidence'))
PHASE='configuration'
CHECKS=frozenset(('all_loaded_images_bound_to_inspected_oci','owned_network_is_internal',
    'packaged_browser_verified_https_ready','untrusted_browser_certificate_rejected','actual_angular_static_index_and_csp_served',
    'actual_angular_entrypoint_in_index','actual_angular_entrypoint_served','anonymous_packaged_api_denied',
    'root_config_not_served','materialized_config_not_served','private_key_not_served','browser_port_published_only_on_loopback',
    'browser_internal_network_has_no_host_port_mapping',
    'actual_nonroot_readonly_capability_and_private_file_boundaries','event_publisher_mismatched_role_fails_closed_without_private_output',
    'event_consumer_mismatched_role_fails_closed_without_private_output','owned_containers_network_and_private_fixture_cleaned',
    'image_inventory_invalid','image_oci_reinspection_failed','image_source_labels_mismatch','image_inventory_differs_from_oci',
    'image_loaded_inspection_unavailable','image_loaded_metadata_invalid','image_loaded_identity_mismatch'))


class SmokeFailure(RuntimeError):
    def __init__(self,check,metadata=None,readiness=None):self.check=check;self.metadata=metadata;self.readiness=readiness


def stage(name):
    global PHASE
    if name not in STAGES:raise ValueError('Invalid fixed smoke stage')
    PHASE=name


def failure(error):
    value={'status':'failed','stage':PHASE,
        'check':error.check if isinstance(error,SmokeFailure) and error.check in CHECKS else 'runtime_boundary_unavailable'}
    if isinstance(error,SmokeFailure) and error.metadata is not None:value['image_identity']=public_identity(error.metadata)
    if isinstance(error,SmokeFailure) and error.readiness is not None:value['readiness']=public_readiness(error.readiness)
    return value


ERROR_CATEGORIES=frozenset(('none','connection_refused','timeout','tls_verification','tls_protocol','connection_reset','http_protocol','os_error'))
LOG_MARKERS={'Browser runtime started with verified identity trust.':'started',
    'Browser runtime failed; private details withheld.':'runtime_failed',
    'Packaged runtime configuration refused; private details withheld.':'configuration_refused',
    'Private configuration refused; no secret values exported.':'materialization_refused',
    'Signing key set rejected; restart required.':'signing_keys_rejected',
    'Signing key refresh unavailable.':'signing_keys_unavailable'}


def public_readiness(value):
    value=value if isinstance(value,dict) else {}
    status=value.get('last_http_status');code=value.get('exit_code')
    category=value.get('last_error');markers=value.get('startup_markers')
    if not isinstance(markers,list):markers=[]
    return {'last_http_status':status if type(status) is int and 100<=status<=599 else None,
        'last_error':category if isinstance(category,str) and category in ERROR_CATEGORIES else 'os_error',
        'running':value.get('running') if type(value.get('running')) is bool else None,
        'exit_code':code if type(code) is int and 0<=code<=255 else None,
        'oom_killed':value.get('oom_killed') if type(value.get('oom_killed')) is bool else None,
        'probe_mode':value.get('probe_mode') if value.get('probe_mode') in ('published-loopback','internal-direct') else None,
        'startup_markers':[marker for marker in LOG_MARKERS.values() if marker in markers]}


def error_category(error):
    if isinstance(error,ssl.SSLCertVerificationError):return 'tls_verification'
    if isinstance(error,ssl.SSLError):return 'tls_protocol'
    if isinstance(error,ConnectionRefusedError):return 'connection_refused'
    if isinstance(error,(TimeoutError,socket.timeout)):return 'timeout'
    if isinstance(error,ConnectionResetError):return 'connection_reset'
    if isinstance(error,http.client.HTTPException):return 'http_protocol'
    return 'os_error'


def readiness_details(docker,name,last,mode):
    value=dict(last,probe_mode=mode)
    try:
        state=json.loads(docker('inspect',name).stdout)[0]['State']
        value.update(running=state.get('Running'),exit_code=state.get('ExitCode'),oom_killed=state.get('OOMKilled'))
    except Exception:pass
    try:
        logs=docker('logs','--tail','20',name)
        value['startup_markers']=[LOG_MARKERS[line] for line in (logs.stdout+logs.stderr).splitlines() if line in LOG_MARKERS]
    except Exception:pass
    return public_readiness(value)


def probe_route(container,network,subnet,port):
    expected=[{'HostIp':'127.0.0.1','HostPort':str(port)}]
    if container['HostConfig'].get('PortBindings',{}).get('18447/tcp')!=expected:
        raise ValueError('Explicit loopback publication request required')
    effective=container['NetworkSettings'].get('Ports',{}).get('18447/tcp')
    if effective==expected:return 'published-loopback',None
    if effective not in (None,[]):raise ValueError('Unexpected effective port publication')
    # Internal-only bridges may suppress publication. Probe only the inspected
    # owned-network address; retain localhost TLS verification and Host origin.
    address=container['NetworkSettings']['Networks'][network]['IPAddress']
    if ipaddress.IPv4Address(address) not in ipaddress.IPv4Network(subnet):raise ValueError('Container address outside owned network')
    return 'internal-direct',(address,18447)


def public_identity(metadata):
    """Only digest/descriptor identifiers can enter diagnostic evidence."""
    result={}
    if not isinstance(metadata,dict):return result
    if metadata.get('role') in ROLES:result['role']=metadata['role']
    for field in ('loaded_id','descriptor_digest','expected_manifest_digest','expected_config_digest'):
        value=metadata.get(field)
        result[field]=value if isinstance(value,str) and compiler.DIGEST.fullmatch(value) else None
    media=metadata.get('descriptor_media_type')
    known={'application/vnd.oci.image.manifest.v1+json','application/vnd.oci.image.index.v1+json',
           'application/vnd.docker.distribution.manifest.v2+json','application/vnd.docker.distribution.manifest.list.v2+json'}
    result['descriptor_media_type']=media if isinstance(media,str) and media in known else None
    size=metadata.get('descriptor_size')
    result['descriptor_size']=size if type(size) is int and 0<=size<=16*1024*1024 else None
    return result


def bind_loaded_image(role,loaded,descriptor,config_digest):
    if not isinstance(loaded,dict):raise SmokeFailure('image_loaded_metadata_invalid',{'role':role})
    identity=loaded.get('Id');target=loaded.get('Descriptor')
    details={'role':role,'loaded_id':identity,'expected_manifest_digest':descriptor['digest'],'expected_config_digest':config_digest}
    if isinstance(target,dict):details.update(descriptor_digest=target.get('digest'),descriptor_media_type=target.get('mediaType'),descriptor_size=target.get('size'))
    exact_manifest=(isinstance(target,dict) and target.get('digest')==descriptor['digest'] and
        target.get('mediaType')=='application/vnd.oci.image.manifest.v1+json' and
        type(target.get('size')) is int and target['size']==descriptor['size'])
    # Classic Docker keys by config digest. Moby's containerd image store keys
    # by target.Digest and returns that target as Descriptor (upstream source:
    # github.com/moby/moby/blob/master/daemon/containerd/image_inspect.go).
    # Never accept an arbitrary index or ID just because labels happen to match.
    if identity==config_digest and (target is None or exact_manifest):kind='config'
    elif identity==descriptor['digest'] and exact_manifest:kind='oci-manifest'
    else:raise SmokeFailure('image_loaded_identity_mismatch',details)
    return {'config_digest':config_digest,'manifest_digest':descriptor['digest'],'runtime_id':identity,'identity_kind':kind}


class Docker:
    def __init__(self,runtime):self.argv=portability.docker(runtime)
    def __call__(self,*args,timeout=30,check=True):
        try:
            result=subprocess.run(self.argv+list(args),capture_output=True,text=True,timeout=timeout)
        except (OSError,subprocess.TimeoutExpired):raise RuntimeError('Container command unavailable') from None
        if len(result.stdout)>65536 or len(result.stderr)>65536:raise RuntimeError('Container response exceeded bound')
        if check and result.returncode:raise RuntimeError('Container command refused; private details withheld')
        return result


def verified_images(manifest,docker):
    if not isinstance(manifest,dict) or set(manifest)!={'source_commit','images'} or not re.fullmatch(r'[0-9a-f]{40}',manifest.get('source_commit','')):
        raise SmokeFailure('image_inventory_invalid')
    if not isinstance(manifest['images'],dict) or set(manifest['images'])!=set(ROLES):raise SmokeFailure('image_inventory_invalid')
    result={}
    for role in ROLES:
        entry=manifest['images'][role]
        if not isinstance(entry,dict) or set(entry)!={'image','oci_layout','secret','keys','runtime_reference'}:
            raise SmokeFailure('image_inventory_invalid',{'role':role})
        reference=entry['runtime_reference']
        try:inspected=runtime_images.inspect(role,entry['oci_layout'],reference,manifest['source_commit'])
        except (OSError,ValueError,KeyError,TypeError) as error:
            code='image_source_labels_mismatch' if str(error)=='Image source or interface contract mismatch' else 'image_oci_reinspection_failed'
            raise SmokeFailure(code,{'role':role}) from None
        if inspected!={key:value for key,value in entry.items() if key!='runtime_reference'}:
            raise SmokeFailure('image_inventory_differs_from_oci',{'role':role})
        layout=Path(entry['oci_layout']);index=compiler.read_json(layout/'index.json')
        descriptor=index['manifests'][0]
        image=compiler.blob(layout,descriptor)
        digest=image['config']['digest']
        try:raw=docker('image','inspect','--format','{{json .}}',reference).stdout
        except RuntimeError:raise SmokeFailure('image_loaded_inspection_unavailable',{'role':role}) from None
        try:loaded=json.loads(raw)
        except (ValueError,TypeError):raise SmokeFailure('image_loaded_metadata_invalid',{'role':role}) from None
        result[role]=bind_loaded_image(role,loaded,descriptor,digest)
    return result


def certificates(root,gateway):
    now=datetime.datetime.now(datetime.timezone.utc)
    ca_key=rsa.generate_private_key(public_exponent=65537,key_size=2048)
    subject=x509.Name([x509.NameAttribute(NameOID.COMMON_NAME,'Synthetic image-smoke CA')])
    ca=(x509.CertificateBuilder().subject_name(subject).issuer_name(subject).public_key(ca_key.public_key())
        .serial_number(x509.random_serial_number()).not_valid_before(now-datetime.timedelta(minutes=1))
        .not_valid_after(now+datetime.timedelta(hours=1)).add_extension(x509.BasicConstraints(ca=True,path_length=0),critical=True)
        .add_extension(x509.KeyUsage(digital_signature=False,content_commitment=False,key_encipherment=False,
            data_encipherment=False,key_agreement=False,key_cert_sign=True,crl_sign=True,encipher_only=None,decipher_only=None),critical=True)
        .add_extension(x509.SubjectKeyIdentifier.from_public_key(ca_key.public_key()),critical=False)
        .add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(ca_key.public_key()),critical=False)
        .sign(ca_key,hashes.SHA256()))
    key=rsa.generate_private_key(public_exponent=65537,key_size=2048)
    leaf=(x509.CertificateBuilder().subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME,'localhost')]))
        .issuer_name(subject).public_key(key.public_key()).serial_number(x509.random_serial_number())
        .not_valid_before(now-datetime.timedelta(minutes=1)).not_valid_after(now+datetime.timedelta(hours=1))
        .add_extension(x509.SubjectAlternativeName([x509.DNSName('localhost'),x509.IPAddress(ipaddress.ip_address(gateway))]),critical=False)
        .add_extension(x509.BasicConstraints(ca=False,path_length=None),critical=True)
        .add_extension(x509.SubjectKeyIdentifier.from_public_key(key.public_key()),critical=False)
        .add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(ca_key.public_key()),critical=False)
        .add_extension(x509.ExtendedKeyUsage([ExtendedKeyUsageOID.SERVER_AUTH]),critical=False)
        .add_extension(x509.KeyUsage(digital_signature=True,content_commitment=False,key_encipherment=True,
            data_encipherment=False,key_agreement=False,key_cert_sign=False,crl_sign=False,encipher_only=None,decipher_only=None),critical=True)
        .sign(ca_key,hashes.SHA256()))
    values={'ca.pem':ca.public_bytes(serialization.Encoding.PEM),'tls.crt':leaf.public_bytes(serialization.Encoding.PEM),
            'tls.key':key.private_bytes(serialization.Encoding.PEM,serialization.PrivateFormat.PKCS8,serialization.NoEncryption())}
    for name,value in values.items():
        path=root/name;path.write_bytes(value);path.chmod(0o600)
    signing=rsa.generate_private_key(public_exponent=65537,key_size=2048)
    jwk=json.loads(jwt.algorithms.RSAAlgorithm.to_jwk(signing.public_key()))
    return values,{'keys':[dict(jwk,kid='image-smoke',use='sig',alg='RS256')]}


@contextmanager
def issuer_peer(root,gateway,jwks):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self,*_):pass
        def do_GET(self):
            if self.path!='/realms/image-smoke/protocol/openid-connect/certs':
                self.send_error(404);return
            data=json.dumps(jwks).encode();self.send_response(200)
            self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(data)))
            self.end_headers();self.wfile.write(data)
    server=ThreadingHTTPServer((gateway,0),Handler)
    tls=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);tls.minimum_version=ssl.TLSVersion.TLSv1_2
    tls.load_cert_chain(root/'tls.crt',root/'tls.key');server.socket=tls.wrap_socket(server.socket,server_side=True)
    thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
    try:yield f'https://{gateway}:{server.server_port}'
    finally:server.shutdown();server.server_close();thread.join(timeout=3)


def projected(root,role,config,values):
    target=root/role;target.mkdir(mode=0o750);target.chmod(0o750)
    content={'config.json':compiler.encoded(config)}
    if role=='browser-session':content.update(values)
    else:content.update({'broker-ca.pem':values['ca.pem'],'database-ca.pem':values['ca.pem']})
    for name,data in content.items():
        path=target/name;path.write_bytes(data);path.chmod(0o440)
    # Hosted CI only: exercise Kubernetes-like root-owned fsGroup-readable keys.
    commands=[['sudo','-n','chgrp','10001',str(target)],
              ['sudo','-n','chown','0:10001',*[str(target/name) for name in sorted(content)]]]
    for command in commands:
        result=subprocess.run(command,capture_output=True,timeout=10)
        if result.returncode:raise RuntimeError('Projected ownership setup unavailable')
    return target


def worker_config(role,gateway):
    # Structurally valid delivery settings with deliberately mismatched role.
    mode='reference-consumer' if role=='event-publisher' else 'publisher'
    value={'mode':mode,'broker_endpoint':f'tls://{gateway}:4222','broker_user':'image-smoke',
        'broker_password':secrets.token_urlsafe(32),'broker_ca':'/run/private/config/broker-ca.pem',
        'database_host':gateway,'database_port':5432,'database_name':'synthetic','database_user':'synthetic',
        'database_password':secrets.token_urlsafe(32),'database_transport':'verify-full','database_ca':'/run/private/config/database-ca.pem',
        'batch_size':1,'lease_seconds':5,'poll_seconds':.1,'operation_timeout_seconds':2,
        'retry_attempts':1,'retry_base_seconds':.1,'retry_cap_seconds':.1,'shutdown_seconds':2}
    if mode=='reference-consumer':value.update(account_id=62654,durable='image-smoke')
    return value


def launch_args(name,network,owner,projection,image_id,port=None):
    args=['run','-d','--name',name,'--label',LABEL+'='+owner,'--network',network,
          '--user','10001:10001','--read-only','--cap-drop','ALL','--security-opt','no-new-privileges:true',
          '--pids-limit','64','--memory','256m','--cpus','1',
          '--mount',f'type=bind,src={projection},dst=/run/projected,readonly',
          '--tmpfs','/run/private:rw,noexec,nosuid,nodev,uid=10001,gid=10001,mode=0700,size=16m',
          '--tmpfs','/tmp:rw,noexec,nosuid,nodev,uid=10001,gid=10001,mode=0700,size=8m']
    if port is not None:args+=['--publish',f'127.0.0.1:{port}:18447']
    return args+[image_id]


def request(port,context,path,connect_to=None):
    connection=http.client.HTTPSConnection('localhost',port,context=context,timeout=3)
    if connect_to is not None:
        def connect():
            raw=socket.create_connection(connect_to,timeout=3)
            try:connection.sock=context.wrap_socket(raw,server_hostname='localhost')
            except BaseException:raw.close();raise
        connection.connect=connect
    try:
        connection.request('GET',path);response=connection.getresponse()
        data=response.read(4*1024*1024+1)
        if len(data)>4*1024*1024:raise ValueError('Browser smoke response exceeded bound')
        return response.status,dict(response.getheaders()),data
    finally:connection.close()


PRIVATE_PROBE='''import json,os,stat
from pathlib import Path
def file(path):
 s=os.stat(path);return [s.st_uid,s.st_gid,stat.S_IMODE(s.st_mode)]
status=dict(line.split(':',1) for line in Path('/proc/self/status').read_text().splitlines() if ':' in line)
mounts=[line.split(' - ',1) for line in Path('/proc/self/mountinfo').read_text().splitlines()]
private_fs=[after.split()[0] for before,after in mounts if before.split()[4]=='/run/private']
blocked=False
try:
 fd=os.open('/rootfs-image-smoke',os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600);os.close(fd)
except OSError:blocked=True
print(json.dumps({'uid':os.getuid(),'gid':os.getgid(),'projected':file('/run/projected/config.json'),
 'private':file('/run/private/config/config.json'),'directory':file('/run/private/config'),
 'no_new_privileges':status['NoNewPrivs'].strip(),'capabilities':status['CapEff'].strip(),'root_write_denied':blocked,
 'private_filesystem':private_fs}))
'''


def check_restrictions(container,probe):
    config=container['Config'];host=container['HostConfig']
    if config.get('User')!='10001:10001' or host.get('ReadonlyRootfs') is not True or host.get('CapDrop')!=['ALL']:
        raise ValueError('Container workload restrictions not applied')
    if not any(item in ('no-new-privileges','no-new-privileges:true') for item in host.get('SecurityOpt',[])):
        raise ValueError('Container privilege escalation not disabled')
    mounts={item['Destination']:item for item in container['Mounts']}
    private_tmpfs=mounts.get('/run/private',{}).get('Type')=='tmpfs' or '/run/private' in host.get('Tmpfs',{})
    if mounts.get('/run/projected',{}).get('RW') is not False or not private_tmpfs:
        raise ValueError('Private configuration mount boundary not applied')
    expected={'uid':10001,'gid':10001,'projected':[0,10001,0o440],
        'private':[10001,10001,0o600],'directory':[10001,10001,0o700],
        'no_new_privileges':'1','capabilities':'0000000000000000','root_write_denied':True,'private_filesystem':['tmpfs']}
    if probe!=expected:raise ValueError('Materialized identity or file boundary not enforced')


def cleanup_owned(docker,names,network,owner):
    failures=[]
    for kind,name in [('container',name) for name in reversed(names)]+[('network',network)]:
        try:
            result=docker(kind,'inspect','--format','{{index .'+('Config.Labels' if kind=='container' else 'Labels')+' "'+LABEL+'"}}',name,check=False,timeout=10)
            if result.returncode:
                if 'No such' not in result.stderr:failures.append('inspect')
                continue
            if result.stdout.strip()!=owner:failures.append('ownership');continue
            result=docker(kind,'rm',*(['-f'] if kind=='container' else []),name,check=False,timeout=15)
            if result.returncode:failures.append('remove')
        except Exception:failures.append('command')
    if failures:raise RuntimeError('Owned smoke cleanup incomplete')


def campaign(runtime,manifest):
    stage('configuration')
    if not portability.isolated_linux() or os.environ.get('GITHUB_ACTIONS')!='true':raise ValueError('Image execution requires isolated hosted Linux')
    runtime=Path(runtime).resolve();runtime.mkdir(parents=True,exist_ok=True)
    stage('verify_images');docker=Docker(runtime);verified=verified_images(manifest,docker)
    owner=secrets.token_hex(12);network='traderx-image-smoke-'+owner;names=[];checks=[]
    def check(condition,name):
        if name not in CHECKS:raise ValueError('Invalid fixed smoke check')
        if not condition:raise SmokeFailure(name)
        checks.append(name)
    check(True,'all_loaded_images_bound_to_inspected_oci')
    with tempfile.TemporaryDirectory(prefix='image-smoke-',dir=runtime) as temporary:
        root=Path(temporary)
        try:
            stage('network')
            docker('network','create','--internal','--label',LABEL+'='+owner,network)
            info=json.loads(docker('network','inspect',network).stdout)[0]
            check(info.get('Internal') is True,'owned_network_is_internal')
            gateway=info['IPAM']['Config'][0]['Gateway'];ipaddress.IPv4Address(gateway)
            stage('issuer');values,jwks=certificates(root,gateway)
            with issuer_peer(root,gateway,jwks) as issuer:
                stage('browser_start')
                with socket.socket() as listener:listener.bind(('127.0.0.1',0));port=listener.getsockname()[1]
                config={'version':1,'origin':f'https://localhost:{port}','issuer':issuer+'/realms/image-smoke',
                    'client_id':'image-smoke-browser','audience':'image-smoke-api','listen_host':'0.0.0.0','listen_port':18447,
                    'certificate':'/run/private/config/tls.crt','key':'/run/private/config/tls.key','ca_file':'/run/private/config/ca.pem',
                    'static_root':'/app/static','backends':{name:issuer for name in sorted(BACKENDS)}}
                projection=projected(root,'browser-session',config,values)
                name='traderx-image-browser-'+owner;names.append(name)
                docker(*launch_args(name,network,owner,projection,verified['browser-session']['runtime_id'],port))
                container=json.loads(docker('inspect',name).stdout)[0]
                probe_mode,connect_to=probe_route(container,network,info['IPAM']['Config'][0]['Subnet'],port)
                context=ssl.create_default_context(cafile=root/'ca.pem')
                stage('browser_ready');deadline=time.monotonic()+30;ready=False
                last={'last_http_status':None,'last_error':'none'}
                while time.monotonic()<deadline:
                    try:
                        status=request(port,context,'/health/ready',connect_to)[0]
                        last={'last_http_status':status,'last_error':'none'}
                        if status==200:ready=True;break
                    except (OSError,http.client.HTTPException) as error:
                        last={'last_http_status':None,'last_error':error_category(error)}
                    state=json.loads(docker('inspect',name).stdout)[0]['State']
                    if not state.get('Running'):break
                    time.sleep(.2)
                if not ready:raise SmokeFailure('packaged_browser_verified_https_ready',readiness=readiness_details(docker,name,last,probe_mode))
                check(True,'packaged_browser_verified_https_ready')
                untrusted=False
                try:request(port,ssl.create_default_context(),'/health/ready',connect_to)
                except ssl.SSLCertVerificationError:untrusted=True
                check(untrusted,'untrusted_browser_certificate_rejected')
                stage('browser_assets');status,headers,body=request(port,context,'/trade',connect_to)
                check(status==200 and b'<app-root' in body and "script-src 'self'" in headers.get('Content-Security-Policy',''),'actual_angular_static_index_and_csp_served')
                matches=re.findall(rb'<script[^>]+src="((?:\./|/)?main-[A-Za-z0-9_-]{6,64}\.js)"',body)
                check(len(matches)==1,'actual_angular_entrypoint_in_index')
                path='/'+matches[0].decode().removeprefix('./').lstrip('/')
                check(request(port,context,path,connect_to)[0]==200,'actual_angular_entrypoint_served')
                stage('browser_boundaries');check(request(port,context,'/api/order-matcher/orders',connect_to)[0]==401,'anonymous_packaged_api_denied')
                for path,label in (('/config.json','root_config_not_served'),('/run/private/config/config.json','materialized_config_not_served'),('/tls.key','private_key_not_served')):
                    check(request(port,context,path,connect_to)[0]==404,label)
                container=json.loads(docker('inspect',name).stdout)[0]
                current_mode,_=probe_route(container,network,info['IPAM']['Config'][0]['Subnet'],port)
                check(current_mode==probe_mode,'browser_port_published_only_on_loopback' if probe_mode=='published-loopback' else 'browser_internal_network_has_no_host_port_mapping')
                probe=json.loads(docker('exec',name,'/usr/local/bin/python','-c',PRIVATE_PROBE).stdout)
                check_restrictions(container,probe);check(True,'actual_nonroot_readonly_capability_and_private_file_boundaries')
                for role in ('event-publisher','event-consumer'):
                    stage('worker_'+role.replace('-','_'))
                    projection=projected(root,role,worker_config(role,gateway),values)
                    name='traderx-image-'+role+'-'+owner;names.append(name)
                    docker(*launch_args(name,network,owner,projection,verified[role]['runtime_id']))
                    code=docker('wait',name,timeout=20).stdout.strip()
                    logs=docker('logs','--tail','10',name)
                    check(code=='2' and (logs.stdout+logs.stderr).strip()==REFUSAL,role.replace('-','_')+'_mismatched_role_fails_closed_without_private_output')
        finally:
            previous=PHASE;stage('cleanup')
            cleanup_owned(docker,names,network,owner)
            stage(previous)
    check(True,'owned_containers_network_and_private_fixture_cleaned')
    stage('evidence')
    return {'status':'passed','source_commit':manifest['source_commit'],'scope':'Actual inspected Python images: browser startup/static/anonymous boundary and worker configuration rejection only',
        'images':verified,'browser_probe':{'mode':probe_mode,'tls_server_name':'localhost','host_origin_verified':True},'checks':checks,'limitations':[
            'Synthetic TLS signing-key peer supplies no real OIDC login or business API; no browser trading or issuer-provider integration claim.',
            'Workers deliberately reject mismatched roles before connecting; actual image-based PostgreSQL/NATS delivery remains a separate gate.',
            'When an internal-only bridge suppresses host publication, verified TLS probes use its owned container address; localhost publication is not claimed in that mode.',
            'This is an isolated Docker smoke, not Kubernetes admission, image signature verification, or cumulative deployed-state acceptance.']}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-dir',type=Path,required=True);parser.add_argument('--images',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    os.umask(0o077)
    def interrupted(*_):raise RuntimeError('Image smoke interrupted')
    old=signal.signal(signal.SIGTERM,interrupted)
    try:
        value=campaign(args.runtime_dir,compiler.read_json(args.images))
        args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_bytes(compiler.encoded(value))
        print('Inspected image startup and configuration smoke passed; business delivery remains a separate gate.')
    except Exception as error:
        print(json.dumps(failure(error),sort_keys=True))
        return 1
    finally:signal.signal(signal.SIGTERM,old)
    return 0


if __name__=='__main__':raise SystemExit(main())
