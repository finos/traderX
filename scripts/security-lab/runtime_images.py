"""Prepare explicit offline OCI build contexts; never build or publish an image."""
import argparse
import ast
import json
import os
from pathlib import Path
import re
import urllib.request

from browser_assets import PublicAssets
import integrated_deployment as compiler
import portability

LOCK=compiler.STATE/'system/runtime-images.lock.json'
SOURCE=compiler.ROOT/'scripts/security-lab'
COMMON={'runtime_launcher.py','private_materializer.py','event_delivery.py'}
FILES={
 'browser-session':COMMON|{'browser_runtime.py','browser_session.py','browser_api.py','browser_assets.py','browser_broker.py','identity_fixture.py'},
 'event-publisher':COMMON|{'delivery_worker.py'},
 'event-consumer':COMMON|{'delivery_worker.py'}}
PACKAGES={
 'browser-session':{'nats-py','simplejson','pyjwt','cryptography','cffi','pycparser'},
 'event-publisher':{'nats-py','simplejson','psycopg','psycopg-binary'},
 'event-consumer':{'nats-py','simplejson','psycopg','psycopg-binary'}}
KEYS={'browser-session':['ca.pem','config.json','tls.crt','tls.key'],
      'event-publisher':['broker-ca.pem','config.json','database-ca.pem'],
      'event-consumer':['broker-ca.pem','config.json','database-ca.pem']}
LIMIT=32*1024*1024


def regular(path,limit=LIMIT):
    path=Path(path)
    if path.is_symlink() or not path.is_file() or path.stat().st_size>limit:raise ValueError('Bounded regular build input required')
    with path.open('rb') as source:value=source.read(limit+1)
    if len(value)>limit:raise ValueError('Build input exceeded limit')
    return value


def fetch_wheels(output):
    if not portability.isolated_linux() or os.environ.get('GITHUB_ACTIONS')!='true':
        raise ValueError('Wheel download requires isolated hosted runner')
    output.mkdir(parents=True,exist_ok=False)
    for item in compiler.read_json(LOCK)['wheels'].values():
        if not item['url'].startswith('https://files.pythonhosted.org/') or item['size']>LIMIT:raise ValueError('Unreviewed wheel source')
        with urllib.request.urlopen(item['url'],timeout=30) as response:data=response.read(LIMIT+1)
        if len(data)!=item['size'] or compiler.sha(data)!=item['sha256']:raise ValueError('Wheel bytes differ from release pin')
        (output/item['filename']).write_bytes(data)


def argv(role):
    command=['/usr/local/bin/python','/opt/traderx/private_materializer.py','--source','/run/projected','--target','/run/private/config']
    command += [value for key in KEYS[role] for value in ('--key',key)]
    return command+['--','/usr/local/bin/python','/opt/traderx/runtime_launcher.py','--role',role,'--config','/run/private/config/config.json']


def frontend(root):
    root=Path(root)
    if not root.is_absolute() or root.resolve()!=root:raise ValueError('Absolute non-symlink generated frontend required')
    generation=compiler.read_json(root/'security-generation.json')
    if not generation.get('inputs') or not generation.get('files'):raise ValueError('Generated frontend source inventory required')
    for relative,digest in generation['inputs'].items():
        path=compiler.ROOT/relative
        if Path(relative).is_absolute() or '..' in Path(relative).parts or compiler.sha(regular(path))!=digest:
            raise ValueError('Frontend generator source drift')
    for relative,digest in generation['files'].items():
        if Path(relative).is_absolute() or '..' in Path(relative).parts or compiler.sha(regular(root/relative))!=digest:
            raise ValueError('Generated frontend source drift')
    static=root/'dist/main-application/browser'
    if static.resolve()!=static:raise ValueError('Compiled frontend cannot traverse symlinks')
    assets=PublicAssets(static)
    if not any(re.fullmatch(r'/main-[A-Za-z0-9_-]{6,64}\.js',name) for name in assets.files):
        raise ValueError('Built Angular entrypoint required')
    # PublicAssets filters to the exact public file allowlist. Unrecognized files,
    # source maps, environments, node_modules and generation metadata stay outside.
    return {'static'+name:value[0] for name,value in assets.files.items()}


def prepare(role,wheelhouse,output,revision,frontend_root=None):
    if role not in FILES or not re.fullmatch(r'[0-9a-f]{40}',revision):raise ValueError('Explicit role and source revision required')
    if role=='browser-session' and frontend_root is None:raise ValueError('Built protected Angular frontend required')
    if role!='browser-session' and frontend_root is not None:raise ValueError('Workers have no frontend inputs')
    lock=compiler.read_json(LOCK);source=compiler.source_manifest()
    files={}
    for name in sorted(FILES[role]):files['source/'+name]=regular(SOURCE/name)
    for name in FILES[role]:
        for node in ast.walk(ast.parse(files['source/'+name])):
            modules=[]
            if isinstance(node,ast.Import):modules=[value.name.split('.')[0] for value in node.names]
            if isinstance(node,ast.ImportFrom) and node.module:modules=[node.module.split('.')[0]]
            for module in modules:
                if module=='verify_account_authorization' and name=='browser_session.py':continue
                if name=='runtime_launcher.py' and module in ('browser_runtime','delivery_worker'):continue
                if (SOURCE/(module+'.py')).is_file() and module+'.py' not in FILES[role]:raise ValueError('Runtime import absent from source allowlist')
    requirements=[]
    for name in sorted(PACKAGES[role]):
        item=lock['wheels'][name];data=regular(Path(wheelhouse)/item['filename'])
        if len(data)!=item['size'] or compiler.sha(data)!=item['sha256']:raise ValueError('Unverified wheel in build context')
        files['wheels/'+item['filename']]=data
        requirements.append(name+'=='+item['version']+' --hash=sha256:'+item['sha256'])
    files['requirements.txt']=('\n'.join(requirements)+'\n').encode()
    if frontend_root is not None:files.update(frontend(frontend_root))
    labels={'org.opencontainers.image.revision':revision,'traderx.security-lab.role':role,
            'traderx.security-lab.source-manifest':source['sha256'],'traderx.security-lab.config-interface':'private-config-v1'}
    if role=='browser-session':labels.update({'traderx.security-lab.bind-address':'0.0.0.0','traderx.security-lab.transport':'https','traderx.security-lab.port':'18447'})
    # The wheels are installed in a builder stage so their archives never enter
    # the final filesystem. No network is needed by either stage's RUN steps.
    dockerfile=[f'FROM {lock["base"]["reference"]} AS dependencies','COPY wheels/ /wheels/','COPY requirements.txt /requirements.txt',
        'RUN python -m pip install --no-index --find-links=/wheels --require-hashes --no-deps --no-compile --no-cache-dir --target=/packages -r /requirements.txt',
        f'FROM {lock["base"]["reference"]}',
        'ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PYTHONPATH=/opt/traderx:/opt/packages',
        'COPY --from=dependencies /packages/ /opt/packages/',
        'COPY --chmod=0555 source/ /opt/traderx/',
        'RUN mkdir -p /run/projected /run/private /tmp && chown 10001:10001 /run/private /tmp && chmod 0700 /run/private',
        'WORKDIR /opt/traderx']
    if role=='browser-session':dockerfile+=['COPY --chmod=0555 static/ /app/static/','EXPOSE 18447']
    dockerfile += ['LABEL '+name+'='+json.dumps(value) for name,value in sorted(labels.items())]
    dockerfile += ['USER 10001:10001','ENTRYPOINT '+json.dumps(argv(role)),'CMD []']
    files['Dockerfile']=('\n'.join(dockerfile)+'\n').encode()
    files['.dockerignore']=b'**\n!Dockerfile\n!requirements.txt\n!source/\n!source/**\n!wheels/\n!wheels/**\n!static/\n!static/**\n'
    record={'schema_version':1,'role':role,'platform':lock['platform'],'source_commit':revision,'source_manifest':source,
            'base':lock['base'],'keys':KEYS[role],'command':argv(role),
            'context_files':{name:compiler.sha(data) for name,data in sorted(files.items())},
            'status':'build-context-prepared-not-image-built-or-runtime-accepted'}
    files['image-build.json']=compiler.encoded(record)
    output=Path(output);output.mkdir(parents=True,exist_ok=False)
    for name,data in files.items():
        path=output/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
    return record


def inspect(role,layout,name,revision):
    if role not in FILES or not re.fullmatch(r'[a-z0-9][a-z0-9./:_-]+',name):raise ValueError('Explicit local image reference required')
    layout=Path(layout).resolve();index=compiler.read_json(layout/'index.json')
    if len(index.get('manifests',[]))!=1:raise ValueError('Single-platform unattested local export required')
    entry={'image':name+'@'+index['manifests'][0]['digest'],'oci_layout':str(layout),'secret':'private-'+role,'keys':KEYS[role]}
    actual=compiler.image(role,entry,compiler.source_manifest(),revision,'linux/amd64')
    if actual!=argv(role):raise ValueError('Packaged launcher command changed')
    return entry


def main():
    parser=argparse.ArgumentParser(description=__doc__);commands=parser.add_subparsers(dest='action',required=True)
    fetch=commands.add_parser('fetch-wheels');fetch.add_argument('--output',type=Path,required=True)
    build=commands.add_parser('prepare');build.add_argument('--role',choices=FILES,required=True)
    build.add_argument('--wheelhouse',type=Path,required=True);build.add_argument('--frontend-root',type=Path)
    build.add_argument('--source-commit',required=True);build.add_argument('--output',type=Path,required=True)
    check=commands.add_parser('inspect');check.add_argument('--role',choices=FILES,required=True)
    check.add_argument('--layout',type=Path,required=True);check.add_argument('--image-name',required=True);check.add_argument('--source-commit',required=True)
    args=parser.parse_args()
    if args.action=='fetch-wheels':fetch_wheels(args.output)
    elif args.action=='prepare':print(json.dumps(prepare(args.role,args.wheelhouse,args.output,args.source_commit,args.frontend_root),sort_keys=True))
    else:print(json.dumps(inspect(args.role,args.layout,args.image_name,args.source_commit),sort_keys=True))


if __name__=='__main__':main()
