"""Non-runnable OCI metadata fixtures for API-schema/admission tests only."""
import io
from pathlib import Path
import tarfile

import integrated_deployment as compiler

NAMESPACE='traderx-security-lab-admission'


def put(layout,value,metadata=True):
    data=compiler.encoded(value) if metadata else value
    digest=compiler.sha(data);path=layout/'blobs/sha256'/digest
    path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
    return {'digest':'sha256:'+digest,'size':len(data)}


def image(root,role,source,revision,alter=None):
    layout=Path(root)/role;layout.mkdir(exist_ok=True)
    keys=['ca.pem','config.json']
    argv=['/usr/bin/java','-jar','/app/candidate.jar']
    if role in compiler.WORKERS:
        argv=['/usr/local/bin/python','/opt/traderx/private_materializer.py','--source','/run/projected','--target','/run/private/config']
        argv += [part for key in keys for part in ('--key',key)]
        argv += ['--','/usr/local/bin/python','/opt/traderx/entrypoint.py','--config','/run/private/config/config.json']
    if role in compiler.JAVA_ROLES:
        from java_runtime import role_contract
        keys=list(role_contract(role)['keys'])
        argv=['/usr/local/bin/python','/opt/traderx/private_materializer.py','--source','/run/projected','--target','/run/private/config']
        argv += [part for key in keys for part in ('--key',key)]
        argv += ['--','/usr/local/bin/python','/opt/traderx/java_runtime.py','--role',role,'--config','/run/private/config/config.json']
    if role=='people-service':
        from people_runtime import FILES
        keys=sorted(FILES)
        argv=['/usr/local/bin/python','/opt/traderx/people_runtime.py']
    labels={'org.opencontainers.image.revision':revision,'traderx.security-lab.role':role,
        'traderx.security-lab.source-manifest':source['sha256'],'traderx.security-lab.config-interface':'private-config-v1',
        'traderx.security-lab.bind-address':'0.0.0.0','traderx.security-lab.transport':'https','traderx.security-lab.port':str(compiler.ROLES[role]),
        'traderx.security-lab.fixture':'admission-only-non-runnable'}
    # This is a valid empty tar but deliberately contains no executable. It must
    # never be imported into a node or presented as an application image build.
    archive=io.BytesIO()
    with tarfile.open(fileobj=archive,mode='w'):pass
    layer=put(layout,archive.getvalue(),False)
    layer['mediaType']='application/vnd.oci.image.layer.v1.tar'
    config={'architecture':'amd64','os':'linux','rootfs':{'type':'layers','diff_ids':[layer['digest']]},
        'config':{'User':'10001:10001','Entrypoint':argv,'Cmd':[],'Labels':labels}}
    if alter:alter(config)
    descriptor_config=put(layout,config);descriptor_config['mediaType']='application/vnd.oci.image.config.v1+json'
    manifest={'schemaVersion':2,'mediaType':'application/vnd.oci.image.manifest.v1+json','config':descriptor_config,'layers':[layer]}
    descriptor=put(layout,manifest);descriptor['mediaType']='application/vnd.oci.image.manifest.v1+json'
    (layout/'index.json').write_bytes(compiler.encoded({'schemaVersion':2,'manifests':[descriptor]}))
    (layout/'oci-layout').write_bytes(compiler.encoded({'imageLayoutVersion':'1.0.0'}))
    return {'image':'example.invalid/admission-only/'+role+'@'+descriptor['digest'],'oci_layout':str(layout),
        'secret':'private-'+role,'keys':keys}


def contract(root,revision):
    source=compiler.source_manifest()
    return {'schema_version':1,'namespace':NAMESPACE,'platform':'linux/amd64','source_commit':revision,
        'gateway':{'name':'security-gateway','namespace':'traderx-lab-edge'},
        'dependencies':{n:{'port':p,'transport':s,'namespace':NAMESPACE} for n,(p,s) in compiler.DEPS.items()},
        'workloads':{role:image(root,role,source,revision) for role in compiler.ROLES}}
