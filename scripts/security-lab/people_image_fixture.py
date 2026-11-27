"""Hosted-only owned network and restricted actual people image fixture."""
from contextlib import contextmanager
import hashlib
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
import tempfile
import time

import integrated_deployment as compiler
import people_images
import people_runtime
import portability
from resource_operation import operation
import verify_runtime_images as images

ROLE='people-service'
PHASE='configuration'
MARKERS={'People service private configuration refused; details withheld.':'configuration_refused',
 'Couldn\'t find a valid ICU package':'icu_missing','error while loading shared libraries':'native_library_missing',
 'Failed to create CoreCLR':'coreclr_failed','Out of memory':'memory','Unhandled exception':'unhandled_exception',
 'Now listening on:':'listening','Application started.':'started'}

class Failure(RuntimeError):
    def __init__(self,code,diagnostic=None):
        self.code=code;self.diagnostic=diagnostic
        super().__init__('People image acceptance failed; private details withheld')


def verified_image(manifest,docker):
    expected={'source_commit','image','runtime_reference','generated_root','publish_dir','build_report','native_probe'}
    if not isinstance(manifest,dict) or set(manifest)!=expected or not re.fullmatch(r'[0-9a-f]{40}',manifest.get('source_commit','')):
        raise Failure('image_manifest_invalid')
    entry=manifest['image']
    if not isinstance(entry,dict) or set(entry)!={'image','oci_layout','secret','keys'}:raise Failure('image_manifest_invalid')
    value=people_images.inspect(entry['oci_layout'],manifest['runtime_reference'],manifest['source_commit'],
        manifest['generated_root'],manifest['publish_dir'],manifest['build_report'])
    if value!=entry:raise Failure('image_manifest_drift')
    layout=Path(entry['oci_layout']);descriptor=compiler.read_json(layout/'index.json')['manifests'][0]
    metadata=compiler.blob(layout,descriptor)
    loaded=json.loads(docker('image','inspect','--format','{{json .}}',manifest['runtime_reference']).stdout)
    return images.bind_loaded_image(ROLE,loaded,descriptor,metadata['config']['digest'])


def projected(root,config,materials):
    target=root/('projection-'+secrets.token_hex(8));target.mkdir(mode=0o750);target.chmod(0o750)
    generation=target/'..generation';generation.mkdir(mode=0o750);generation.chmod(0o750)
    values={'config.json':compiler.encoded(config),**materials}
    if set(values)!=set(people_runtime.FILES):raise Failure('projection_inventory')
    for name,data in values.items():
        path=generation/name;path.write_bytes(data);path.chmod(0o440)
        (target/name).symlink_to('..data/'+name)
    (target/'..data').symlink_to('..generation')
    commands=[['sudo','-n','chgrp','10001',str(target),str(generation)],
              ['sudo','-n','chown','0:10001',*map(str,sorted(generation.iterdir()))]]
    for command in commands:
        if subprocess.run(command,capture_output=True,timeout=10).returncode:raise Failure('projection_ownership')
    return target


def request(address,context,path,bearer=None,hostname='localhost',method='GET',headers=None):
    connection=http.client.HTTPSConnection(hostname,18089,context=context,timeout=4)
    def connect():
        raw=socket.create_connection((address,18089),timeout=4)
        try:connection.sock=context.wrap_socket(raw,server_hostname=hostname)
        except BaseException:raw.close();raise
    connection.connect=connect
    try:
        values=dict(headers or {})
        if bearer:values['Authorization']='Bearer '+bearer
        connection.request(method,path,headers=values);response=connection.getresponse();data=response.read(65537)
        if len(data)>65536:raise Failure('http_body_bound')
        return response.status,{key.lower():value for key,value in response.getheaders()},data
    finally:connection.close()


def diagnostic(state,text):
    return {'running':state.get('Running') is True,'oom_killed':state.get('OOMKilled') is True,
        'exit_code':state.get('ExitCode') if type(state.get('ExitCode')) is int else None,
        'markers':sorted({value for marker,value in MARKERS.items() if marker in text})}


class PeopleImage:
    def __init__(self,fixture,identity,config,materials):
        self.f=fixture;self.docker=fixture['docker'];self.identity=identity
        self.name='traderx-people-image-'+secrets.token_hex(10)
        self.target=projected(fixture['root'],config,materials);self.sensitive=[materials['server-key.pem'].decode().strip()]
        self.address=None
    def inspect(self):
        info=json.loads(self.docker('container','inspect',self.name).stdout)[0]
        if info['Config'].get('Labels',{}).get(images.LABEL)!=self.f['owner']:raise Failure('ownership')
        return info
    def diagnostics(self):
        logs=self.docker('logs','--tail','120',self.name);raw=logs.stdout+logs.stderr
        if any(value and value in raw for value in self.sensitive):raise Failure('private_output_detected')
        return diagnostic(self.inspect()['State'],raw)
    def request(self,context,path,**kwargs):
        token=kwargs.get('bearer')
        if token and token not in self.sensitive:self.sensitive.append(token)
        return request(self.address,context,path,**kwargs)
    def ready(self,context):
        deadline=time.monotonic()+60
        while time.monotonic()<deadline:
            if not self.inspect()['State'].get('Running'):raise Failure('startup_failed',self.diagnostics())
            try:
                status,_,data=self.request(context,'/health/alive')
                if status==200 and json.loads(data)=={'status':'UP'}:return
            except (OSError,http.client.HTTPException,ValueError):pass
            time.sleep(.2)
        raise Failure('startup_timeout',self.diagnostics())
    @contextmanager
    def run(self):
        self.f['names'].append(self.name)
        args=images.launch_args(self.name,self.f['network'],self.f['owner'],self.target,self.identity['runtime_id'])
        args[args.index('--memory')+1]='256m';args[args.index('--pids-limit')+1]='64'
        args=args[:-1]+['--memory-swap','256m','--log-driver','local','--log-opt','max-size=1m','--log-opt','max-file=1',args[-1]]
        try:
            self.docker(*args);info=self.inspect()
            if info['Image'] not in (self.identity['runtime_id'],self.identity['config_digest']) or info['Config']['Image']!=self.identity['runtime_id']:
                raise Failure('loaded_image_changed')
            self.address=info['NetworkSettings']['Networks'][self.f['network']]['IPAddress']
            if ipaddress.ip_address(self.address) not in self.f['subnet']:raise Failure('network_address')
            yield self
        finally:
            result=self.docker('container','inspect',self.name,check=False)
            if result.returncode==0:
                self.inspect()
                try:self.diagnostics()
                finally:self.docker('rm','-f',self.name)
            elif 'No such' not in result.stderr:raise Failure('cleanup_inspection')


@contextmanager
def fixture(runtime):
    if not portability.isolated_linux() or os.environ.get('GITHUB_ACTIONS')!='true':raise Failure('hosted_linux_required')
    with operation(runtime,'fixture'),tempfile.TemporaryDirectory(prefix='people-image-',dir=runtime) as temporary:
        docker=images.Docker(runtime);owner=secrets.token_hex(12);network='traderx-people-image-'+owner;names=[]
        try:
            docker('network','create','--internal','--label',images.LABEL+'='+owner,network)
            info=json.loads(docker('network','inspect',network).stdout)[0]
            if info.get('Internal') is not True or info.get('Labels',{}).get(images.LABEL)!=owner:raise Failure('network_ownership')
            subnet=ipaddress.IPv4Network(info['IPAM']['Config'][0]['Subnet'])
            yield {'docker':docker,'owner':owner,'network':network,'names':names,'root':Path(temporary),'subnet':subnet}
        finally:images.cleanup_owned(docker,names,network,owner)


PRIVATE_PROBE='''import hashlib,json,os,stat
from pathlib import Path
import sys
sys.path.insert(0,'/opt/traderx')
import people_runtime
root=Path('/run/private/config')
def mode(p):
 s=p.stat();return [s.st_uid,s.st_gid,stat.S_IMODE(s.st_mode)]
c=json.loads((root/'config.json').read_bytes())
env=dict(item.split(b'=',1) for item in Path('/proc/1/environ').read_bytes().split(b'\\0') if b'=' in item)
expected={k.encode():v.encode() for k,v in people_runtime.application_environment(c).items()}
key=(root/'server-key.pem').read_bytes().strip()
cmd=Path('/proc/1/cmdline').read_bytes()
maps=Path('/proc/1/maps').read_text()
print(json.dumps({'files':{p.name:mode(p) for p in root.iterdir()},'directory':mode(root),
 'private_key_exposed':key in cmd or any(key in v for v in env.values()),'exact_environment':env==expected,
 'exact_command':cmd.split(b'\\0')[:-1]==[b'/usr/share/dotnet/dotnet',b'/opt/traderx/PeopleService.WebApi.dll',b'--contentRoot',b'/run/private/config'],
 'directory_sha256':hashlib.sha256(Path('/opt/traderx/MockDirectory/people.json').read_bytes()).hexdigest(),
 'icu_loaded':all(name in maps for name in ('libicuuc.so.72','libicui18n.so.72'))}))
'''
