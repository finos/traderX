"""Instance-scoped hosted Java image fixture; no application acceptance claims."""
from contextlib import contextmanager
import datetime
import http.client
import ipaddress
import json
import os
from pathlib import Path
import re
import secrets
import socket
import ssl
import subprocess
import time

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives.serialization import pkcs12
from cryptography.x509.oid import NameOID, ExtendedKeyUsageOID

import integrated_deployment as compiler
import verify_runtime_images as images
import verify_position_image as position

PORTS={'account-service':18088,'trade-processor':18091}
KEYS={role:tuple(name for name in position.KEYS if role!='trade-processor' or name!='entitlements.properties') for role in PORTS}
Failure=position.Failure
rejected_database_startup=position.rejected_database_startup


def role_contract(role):
    if role not in PORTS:raise ValueError('Unreviewed Java fixture role')
    return PORTS[role],KEYS[role]

def verified_image(manifest, docker, role):
    role_contract(role)
    import java_images
    if (not isinstance(manifest, dict) or set(manifest) !=
            {'source_commit', 'image', 'runtime_reference', 'generated_root', 'build_report'} or
            not isinstance(manifest['source_commit'], str) or not re.fullmatch(r'[0-9a-f]{40}', manifest['source_commit'])):
        raise Failure('image_manifest_invalid')
    entry = manifest['image']
    if not isinstance(entry, dict) or set(entry) != {'image', 'oci_layout', 'secret', 'keys'}:
        raise Failure('image_manifest_invalid')
    inspected = java_images.inspect(entry['oci_layout'], manifest['runtime_reference'], manifest['source_commit'],
                                    manifest['generated_root'], manifest['build_report'], role=role)
    if inspected != entry:
        raise Failure('image_manifest_drift')
    layout = Path(entry['oci_layout'])
    descriptor = compiler.read_json(layout/'index.json')['manifests'][0]
    image = compiler.blob(layout, descriptor)
    loaded = json.loads(docker('image', 'inspect', '--format', '{{json .}}', manifest['runtime_reference']).stdout)
    return images.bind_loaded_image(role, loaded, descriptor, image['config']['digest'])

def certificate_material(role):
    role_contract(role)
    now = datetime.datetime.now(datetime.timezone.utc)
    ca_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    issuer = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, 'Synthetic Java image CA')])
    ca = (x509.CertificateBuilder().subject_name(issuer).issuer_name(issuer).public_key(ca_key.public_key())
          .serial_number(x509.random_serial_number()).not_valid_before(now-datetime.timedelta(minutes=1))
          .not_valid_after(now+datetime.timedelta(hours=1)).add_extension(x509.BasicConstraints(ca=True, path_length=0), True)
          .add_extension(x509.KeyUsage(False, False, False, False, False, True, True, None, None), True)
          .add_extension(x509.SubjectKeyIdentifier.from_public_key(ca_key.public_key()), False)
          .sign(ca_key, hashes.SHA256()))
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    leaf = (x509.CertificateBuilder().subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, role)]))
            .issuer_name(issuer).public_key(key.public_key()).serial_number(x509.random_serial_number())
            .not_valid_before(now-datetime.timedelta(minutes=1)).not_valid_after(now+datetime.timedelta(hours=1))
            .add_extension(x509.BasicConstraints(ca=False, path_length=None), True)
            .add_extension(x509.SubjectAlternativeName([x509.DNSName(role)]), False)
            .add_extension(x509.KeyUsage(True, False, True, False, False, False, False, None, None), True)
            .add_extension(x509.SubjectKeyIdentifier.from_public_key(key.public_key()), False)
            .add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(ca_key.public_key()), False)
            .add_extension(x509.ExtendedKeyUsage([ExtendedKeyUsageOID.SERVER_AUTH]), False).sign(ca_key, hashes.SHA256()))
    password = secrets.token_urlsafe(32)
    bundle = pkcs12.serialize_key_and_certificates(role.encode(), key, leaf, [ca],
                                                   serialization.BestAvailableEncryption(password.encode()))
    return ca.public_bytes(serialization.Encoding.PEM), bundle, password

def projected(root, name, config, materials):
    _,keys=role_contract(config.get('role'))
    content = {'config.json': compiler.encoded(config), **materials}
    if set(content) != set(keys): raise Failure('private_projection_failed')
    target = root/name
    target.mkdir(mode=0o750); target.chmod(0o750)
    for filename, data in content.items():
        path = target/filename; path.write_bytes(data); path.chmod(0o440)
    for command in (['sudo', '-n', 'chgrp', '10001', str(target)],
                    ['sudo', '-n', 'chown', '0:10001', *map(str, sorted(target.iterdir()))]):
        if subprocess.run(command, capture_output=True, timeout=10).returncode:
            raise Failure('private_projection_failed')
    return target

def launch_args(name, f, target, identity, role):
    role_contract(role)
    args = images.launch_args(name, f['network'], f['owner'], target, identity)
    args[args.index('--memory')+1] = '768m'
    args[args.index('--pids-limit')+1] = '128'
    args = [value.replace('/tmp:rw,noexec,nosuid,nodev,uid=10001,gid=10001,mode=0700,size=8m',
                          '/tmp:rw,noexec,nosuid,nodev,uid=10001,gid=10001,mode=0700,size=64m') for value in args]
    return args[:-1] + ['--network-alias', role, args[-1]]

def request(role,address,context,path,bearer=None,hostname=None,method='GET',body=None,headers=None):
    port,_=role_contract(role);hostname=hostname or role
    connection = http.client.HTTPSConnection(hostname, port, context=context, timeout=4)
    def connect():
        raw = socket.create_connection((address, port), timeout=4)
        try: connection.sock = context.wrap_socket(raw, server_hostname=hostname)
        except BaseException: raw.close(); raise
    connection.connect = connect
    try:
        values=dict(headers or {})
        if bearer:values['Authorization']='Bearer '+bearer
        if body is not None:values.setdefault('Content-Type','application/json')
        connection.request(method,path,body=body,headers=values)
        response = connection.getresponse(); data = response.read(1024*1024+1)
        if len(data) > 1024*1024: raise Failure('http_body_bound')
        return response.status, data
    finally: connection.close()

class JavaImage(position.PositionImage):
    """Reuses reviewed diagnostics/owned cleanup without changing position globals."""
    def __init__(self,f,root,identity,config,materials):
        self.role=config.get('role');role_contract(self.role)
        self.f,self.docker,self.identity=f,f['docker'],identity
        self.name='traderx-java-image-'+secrets.token_hex(10)
        self.target=projected(root,self.name,config,materials)
        self.secrets=(config['database']['password'],config['tls']['password'])
        self.address=None

    def request(self,context,path,bearer=None,hostname=None,method='GET',body=None,headers=None):
        return request(self.role,self.address,context,path,bearer,hostname,method,body,headers)

    @contextmanager
    def run(self):
        try:
            self.docker(*launch_args(self.name,self.f,self.target,self.identity['runtime_id'],self.role))
            value=self.inspect()
            if (value['Image'] not in (self.identity['runtime_id'],self.identity['config_digest']) or
                    value['Config']['Image']!=self.identity['runtime_id']):raise Failure('loaded_image_changed')
            self.address=value['NetworkSettings']['Networks'][self.f['network']]['IPAddress']
            ipaddress.IPv4Address(self.address)
            yield self
        except Exception as error:
            try:error.runtime_diagnostic=self.diagnostics()
            except Exception:pass
            raise
        finally:self.cleanup()

    def ready(self,context):
        deadline=time.monotonic()+90
        while time.monotonic()<deadline:
            if self.inspect()['State'].get('Running') is not True:raise Failure('java_startup_failed')
            try:
                status,raw=self.request(context,'/actuator/health')
                if status==200 and json.loads(raw).get('status')=='UP':return
            except (OSError,http.client.HTTPException,ValueError):pass
            time.sleep(.25)
        raise Failure('java_startup_timeout')


def private_java_probe(role):
    port,_=role_contract(role)
    return position.PRIVATE_JAVA_PROBE.replace("=='18090'","=='"+str(port)+"'")


def wrong_database_ca_stopped(app,context):
    deadline=time.monotonic()+90;served_http=False
    while app.inspect()['State'].get('Running') is True and time.monotonic()<deadline:
        try:app.request(context,'/actuator/health');served_http=True
        except (OSError,http.client.HTTPException):pass
        time.sleep(.25)
    return rejected_database_startup(app.diagnostics(),served_http)

