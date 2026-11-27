"""Private-config HTTPS runtime for the generated browser/session candidate."""
import argparse
import json
import os
from pathlib import Path
import re
import signal
import ssl
import stat
import sys
import threading
import urllib.parse
import urllib.request
import jwt

from browser_api import ApiProxy, NoRedirect
from browser_assets import PublicAssets
from browser_broker import BrokerEvents
from browser_session import BrowserServer

MAX_CONFIG=65536
REQUIRED={'version','origin','issuer','client_id','audience','listen_host','listen_port',
          'certificate','key','ca_file','static_root','backends'}


def unique(items):
    value={}
    for key,item in items:
        if key in value:raise ValueError('Duplicate configuration key')
        value[key]=item
    return value


def origin(value,scheme='https'):
    if not isinstance(value,str) or len(value)>512:raise ValueError('Invalid fixed origin')
    parsed=urllib.parse.urlsplit(value)
    if (parsed.scheme!=scheme or not parsed.hostname or parsed.username or parsed.password or
        parsed.path or parsed.query or parsed.fragment or parsed.netloc!=parsed.netloc.lower() or
        value!=scheme+'://'+parsed.netloc or parsed.port is not None and not 1<=parsed.port<=65535):
        raise ValueError('Invalid fixed origin')
    return parsed


def file_path(value,private=False):
    if not isinstance(value,str):raise ValueError('Absolute file required')
    path=Path(value)
    if not path.is_absolute() or path.is_symlink() or not path.is_file():raise ValueError('Absolute regular file required')
    info=path.stat()
    if info.st_size>(65536 if private else 1048576):raise ValueError('Configured file too large')
    if private and (info.st_uid!=os.getuid() or stat.S_IMODE(info.st_mode)!=0o600):
        raise ValueError('Private runtime-owned file required')
    return path


def load_config(filename):
    path=Path(filename)
    if not path.is_absolute():raise ValueError('Absolute config path required')
    descriptor=os.open(path,os.O_RDONLY|os.O_NOFOLLOW)
    with os.fdopen(descriptor,'rb') as stream:
        info=os.fstat(stream.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_uid!=os.getuid() or stat.S_IMODE(info.st_mode)!=0o600:
            raise ValueError('Private runtime-owned config required')
        data=stream.read(MAX_CONFIG+1)
    if len(data)>MAX_CONFIG:raise ValueError('Configuration too large')
    config=json.loads(data,object_pairs_hook=unique)
    if not isinstance(config,dict) or set(config)-REQUIRED-{'broker'} or not REQUIRED<=set(config) or type(config['version']) is not int or config['version']!=1:
        raise ValueError('Unsupported runtime configuration')
    origin(config['origin'])
    issuer=urllib.parse.urlsplit(config['issuer']) if isinstance(config['issuer'],str) else None
    if issuer is None or not re.fullmatch(r'/realms/[A-Za-z0-9_-]{1,64}',issuer.path):raise ValueError('Explicit Keycloak realm required')
    origin(urllib.parse.urlunsplit((issuer.scheme,issuer.netloc,'','','')))
    if issuer.query or issuer.fragment:raise ValueError('Invalid issuer')
    if not isinstance(config['client_id'],str) or not re.fullmatch(r'[A-Za-z0-9_.-]{1,128}',config['client_id']):raise ValueError('Invalid browser client')
    if not isinstance(config['audience'],str) or not re.fullmatch(r'[A-Za-z0-9_.:/-]{1,128}',config['audience']):raise ValueError('Invalid API audience')
    if config['listen_host'] not in ('127.0.0.1','0.0.0.0') or type(config['listen_port']) is not int or not 1<=config['listen_port']<=65535:
        raise ValueError('Explicit permitted listener required')
    for name in ('certificate','key','ca_file'):file_path(config[name],private=name=='key')
    root=Path(config['static_root']) if isinstance(config['static_root'],str) else None
    if root is None or not root.is_absolute() or root.is_symlink() or not root.is_dir():raise ValueError('Absolute static root required')
    if not isinstance(config['backends'],dict) or not config['backends']:raise ValueError('Explicit API backends required')
    for value in config['backends'].values():origin(value)
    # Validate the proxy service allowlist now; the actual CA is loaded at startup.
    ApiProxy(config['backends'])
    if 'broker' in config:
        broker=config['broker']
        if not isinstance(broker,dict) or set(broker)!={'endpoint','ca_file','grants','identities'}:raise ValueError('Invalid broker configuration')
        parsed=origin(broker['endpoint'],'tls')
        if parsed.port is None:raise ValueError('Explicit broker port required')
        file_path(broker['ca_file'])
        grants,identities=broker_policy(broker)
        # Constructor validates bounded scope and distinct credentials without networking.
        BrokerEvents(grants,identities,broker['endpoint'],broker['ca_file'])
    return config


def broker_policy(config):
    if not isinstance(config['grants'],dict) or not isinstance(config['identities'],dict):raise ValueError('Explicit broker grants required')
    identities={}
    for account,value in config['identities'].items():
        if not isinstance(account,str) or not re.fullmatch(r'[1-9][0-9]{0,9}',account):raise ValueError('Canonical account key required')
        identities[int(account)]=value
    grants={}
    for subject,accounts in config['grants'].items():
        if not isinstance(accounts,list) or any(type(account) is not int for account in accounts) or len(accounts)!=len(set(accounts)):
            raise ValueError('Distinct numeric account grants required')
        grants[subject]=set(accounts)
    return grants,identities


def fetch_keys(issuer,context):
    opener=urllib.request.build_opener(urllib.request.ProxyHandler({}),urllib.request.HTTPSHandler(context=context),NoRedirect())
    with opener.open(issuer+'/protocol/openid-connect/certs',timeout=10) as response:
        if response.headers.get_content_type()!='application/json':raise ValueError('Invalid signing key response')
        data=response.read(65537)
        if len(data)>65536:raise ValueError('Signing key response too large')
    value=json.loads(data,object_pairs_hook=unique)
    if not isinstance(value,dict) or not isinstance(value.get('keys'),list) or not 1<=len(value['keys'])<=16 or any(not isinstance(key,dict) for key in value['keys']):
        raise ValueError('Invalid signing key set')
    return value


def serve(config,stopping,refresh_seconds=60):
    context=ssl.create_default_context(cafile=config['ca_file'])
    context.minimum_version=ssl.TLSVersion.TLSv1_2
    assets=PublicAssets(config['static_root'])
    jwks=fetch_keys(config['issuer'],context)
    events=None;server=None
    try:
        if 'broker' in config:
            value=config['broker'];grants,identities=broker_policy(value)
            events=BrokerEvents(grants,identities,value['endpoint'],value['ca_file']).start()
        server=BrowserServer(config['certificate'],config['key'],context,jwks,
            api_proxy=ApiProxy(config['backends'],context),broker_events=events,
            origin=config['origin'],issuer=config['issuer'],client_id=config['client_id'],audience=config['audience'],
            listen_host=config['listen_host'],listen_port=config['listen_port'],assets=assets,configured=True).start()
        print('Browser runtime started with verified identity trust.',flush=True)
        while not stopping.wait(refresh_seconds):
            if server.trust_failed:continue
            try:server.refresh_trust(fetch_keys(config['issuer'],context))
            except (ValueError,KeyError,TypeError,jwt.PyJWTError):
                server.invalidate_trust()
                print('Signing key set rejected; restart required.',file=sys.stderr,flush=True)
            except OSError:
                # No extension of the existing finite trust window on transport failure.
                print('Signing key refresh unavailable.',file=sys.stderr,flush=True)
    finally:
        try:
            if server:server.close()
        finally:
            if events:events.close()


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--config',required=True,type=Path)
    args=parser.parse_args();os.umask(0o077)
    stopping=threading.Event()
    old={number:signal.signal(number,lambda *_:stopping.set()) for number in (signal.SIGTERM,signal.SIGINT)}
    try:
        serve(load_config(args.config),stopping)
        return 0
    except Exception:
        print('Browser runtime failed; private details withheld.',file=sys.stderr)
        return 1
    finally:
        for number,handler in old.items():signal.signal(number,handler)


if __name__=='__main__':raise SystemExit(main())
