"""Owned hosted Chromium trust, real account candidate and synthetic market peers."""
import asyncio
from contextlib import contextmanager
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import shutil
import signal
import ssl
import subprocess
import threading
import time
import uuid

import portability
from identity_fixture import TokenVerifier
from verify_authenticated_trading import JavaService, ROOT, TRADING_AUDIENCE, free_port, trusted_client


def verified_frontend(runtime):
    target=runtime/'application-consumers'
    manifest=json.loads((target/'security-generation.json').read_text())
    for group,base in (('inputs',ROOT),('files',target)):
        for name,digest in manifest[group].items():
            if hashlib.sha256((base/name).read_bytes()).hexdigest()!=digest:raise ValueError('Browser candidate source drift')
    if not (target/'node_modules/puppeteer/package.json').is_file():raise ValueError('Pinned Puppeteer install required')
    return target,manifest


class AccountService(JavaService):
    def __init__(self,runtime,private,environment,context,truststore):
        target=runtime/'account-security-build'
        report=json.loads((runtime/'evidence/account-security-build.json').read_text())
        if report['status']!='built-and-unit-tested-not-deployed':raise ValueError('Tested account build required')
        jar=Path(report['jar']).resolve()
        if not jar.is_relative_to(target.resolve()) or hashlib.sha256(jar.read_bytes()).hexdigest()!=report['jar_sha256']:
            raise ValueError('Account jar drift')
        for group,base in (('inputs',ROOT),('files',target)):
            for name,digest in report['generation'][group].items():
                if hashlib.sha256((base/name).read_bytes()).hexdigest()!=digest:raise ValueError('Account source drift')
        self.entry=dict(report,service='account-service');self.port=free_port();self.origin=f'https://localhost:{self.port}'
        self.env=dict(os.environ,**environment,SERVER_ADDRESS='127.0.0.1',SERVER_PORT=str(self.port))
        self.args=[portability.java(),'-Xmx256m','-XX:MaxMetaspaceSize=192m',
            '-Djavax.net.ssl.trustStore='+str(truststore),'-Djavax.net.ssl.trustStorePassword=changeit',
            '-jar',str(jar),'--server.port='+str(self.port)]
        self.client=trusted_client(context);self.log=private/'account-service.log';self.child=None


class MarketPeers:
    """Explicit synthetic reference/quote peer only; never a fake business API."""
    def __init__(self,cert,key,jwks):
        self.verifier=TokenVerifier(jwks,audience=TRADING_AUDIENCE)
        self.port=free_port();self.origin=f'https://localhost:{self.port}'
        owner=self
        class Handler(BaseHTTPRequestHandler):
            def log_message(self,*args):pass
            def do_GET(self):
                try:
                    header=self.headers.get('Authorization','')
                    if not header.startswith('Bearer '):raise ValueError()
                    owner.verifier.verify(header[7:])
                except Exception:return self.reply(401,{'error':'Unauthorized'})
                stocks=[{'ticker':'IBM','companyName':'International Business Machines'},
                        {'ticker':'MSFT','companyName':'Microsoft'}]
                prices=[{'ticker':symbol,'price':price,'openPrice':price,'closePrice':price,
                    'asOf':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'source':'synthetic-journey'}
                    for symbol,price in (('IBM',99),('MSFT',200))]
                if self.path=='/stocks':return self.reply(200,stocks)
                if self.path=='/prices':return self.reply(200,prices)
                for price in prices:
                    if self.path=='/prices/'+price['ticker']:return self.reply(200,price)
                return self.reply(404,{'error':'Not found'})
            def reply(self,status,value):
                data=json.dumps(value).encode();self.send_response(status)
                self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(data)))
                self.end_headers();self.wfile.write(data)
        tls=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);tls.minimum_version=ssl.TLSVersion.TLSv1_2;tls.load_cert_chain(cert,key)
        self.server=ThreadingHTTPServer(('127.0.0.1',self.port),Handler)
        self.server.socket=tls.wrap_socket(self.server.socket,server_side=True);self.thread=None

    def start(self):
        self.thread=threading.Thread(target=self.server.serve_forever,daemon=True);self.thread.start();return self

    def close(self):
        if self.thread:self.server.shutdown()
        self.server.server_close()
        if self.thread:self.thread.join(timeout=5)


@contextmanager
def chromium_trust(certificate):
    # The user authorized hosted-only execution. Never alter local Chrome or HOME.
    if not portability.isolated_linux():raise ValueError('Chromium trust requires isolated hosted Linux')
    certutil=shutil.which('certutil')
    if not certutil:raise ValueError('Hosted certutil required')
    directory=Path.home()/'.pki/nssdb'
    if directory.is_symlink():raise ValueError('Symlink NSS database refused')
    directory.mkdir(parents=True,exist_ok=True)
    database='sql:'+str(directory);nickname='traderx-journey-'+uuid.uuid4().hex
    def run(*args):
        try:subprocess.run([certutil,*args],capture_output=True,check=True,timeout=20)
        except (subprocess.SubprocessError,OSError):raise RuntimeError('Owned Chromium trust operation failed') from None
    if not (directory/'cert9.db').exists():run('-N','--empty-password','-d',database)
    installed=False
    try:
        run('-A','-d',database,'-n',nickname,'-t','C,,','-i',str(certificate));installed=True
        yield
    finally:
        if installed:run('-D','-d',database,'-n',nickname)


def order_id(value):
    if not isinstance(value,str) or not re.fullmatch(r'ord-013-[0-9]{1,24}',value):raise ValueError('Invalid journey order identity')
    return value


def driver_checks(node,driver):
    script='const {CHECK_IDS}=await import(process.argv[1]);process.stdout.write(JSON.stringify(CHECK_IDS));'
    try:
        raw=subprocess.run([node,'--input-type=module','-e',script,driver.as_uri()],capture_output=True,check=True,timeout=15).stdout
        if len(raw)>8192:raise ValueError()
        checks=json.loads(raw)
        if not isinstance(checks,list) or not 8<=len(checks)<=40 or any(not isinstance(item,str) or not re.fullmatch(r'[a-z][a-z0-9_-]{1,80}',item) for item in checks) or len(checks)!=len(set(checks)):
            raise ValueError()
        return checks
    except (subprocess.SubprocessError,OSError,ValueError):raise RuntimeError('Browser driver check contract unavailable') from None


def driver_failure(value):
    phases={'configuration','browser_launch','trader_login','trader_order','ready_for_price','ready_for_delivery',
            'settled_grids','cancel_order','logout','reader_login','reader_denials'}
    phases.update(role+'_login_'+step for role in ('trader','reader') for step in
        ('initial_page','signin_link','provider_navigation','credentials','username','password','callback','accounts','account_menu'))
    phases.update(flow+'_'+step for flow in ('trader_order','cancel_order','reader_order') for step in
        ('open_ticket','stock_input','typeahead','terms','submit_click','submit_response','denial_message','open_row'))
    phases.update(('cancel_order_scroll','cancel_order_click','cancel_order_response','cancel_order_removed'))
    phase=value.get('phase') if value.get('phase') in phases else 'unclassified'
    codes={'timeout','certificate_trust','tls_failure','connection_unavailable','unexpected_error','check_failed',
        'unsupported_api','element_not_clickable','context_destroyed',
        'unexpected_login_origin','unexpected_callback_origin','account_snapshot_missing','account_label_missing',
        'order_submission_rejected','invalid_created_order','logout_unconfirmed','initial_settlement_snapshots_missing',
        'actual_broker_notifications_missing','notification_snapshots_not_refreshed','settled_trade_not_rendered',
        'position_valuation_not_rendered','cancel_rejected','visible_control_missing','coordinator_timeout'}
    code=value.get('error') if value.get('error') in codes else 'unclassified'
    supplied=value.get('diagnostics',{});safe={}
    if isinstance(supplied,dict):
        for name in ('pageErrors','cspErrors','sessionStatus','accountStatus','orderStatus','cancelStatus'):
            item=supplied.get(name)
            if type(item) is int and 0<=item<=1000:safe[name]=item
        if supplied.get('location') in ('app','issuer','other','unknown'):safe['location']=supplied['location']
        values=supplied.get('angularCodes')
        if isinstance(values,list) and len(values)<=8 and all(isinstance(item,str) and re.fullmatch(r'NG[0-9]{4,6}',item) for item in values):safe['angularCodes']=values
        directives=supplied.get('cspDirectives')
        allowed={'default-src','script-src','script-src-elem','style-src','style-src-elem','font-src','img-src','connect-src','frame-src','frame-ancestors','form-action','base-uri','object-src'}
        if isinstance(directives,list) and len(directives)<=len(allowed) and all(isinstance(item,str) and item in allowed for item in directives):safe['cspDirectives']=directives
    return 'Browser journey driver failed during '+phase+'; code='+code+'; diagnostics='+json.dumps(safe,sort_keys=True)+'; private diagnostics withheld'


async def run_driver(node,driver,config,private,stage,expected_checks):
    stderr=private/'browser-driver.log'
    with stderr.open('xb') as output:
        stderr.chmod(0o600)
        child=await asyncio.create_subprocess_exec(node,str(driver),'--config',str(config),
            stdin=asyncio.subprocess.PIPE,stdout=asyncio.subprocess.PIPE,stderr=output,start_new_session=True)
        try:
            expected=['ready_for_price','ready_for_delivery'];position=0;created=None
            while True:
                raw=await asyncio.wait_for(child.stdout.readline(),timeout=120)
                if not raw or len(raw)>8192:raise RuntimeError('Browser driver protocol unavailable')
                try:value=json.loads(raw)
                except (ValueError,UnicodeError):raise RuntimeError('Invalid browser driver protocol') from None
                if not isinstance(value,dict):raise RuntimeError('Invalid browser driver protocol')
                if value.get('status')=='failed':
                    raise RuntimeError(driver_failure(value))
                if 'stage' in value:
                    if position>=len(expected) or set(value)!={'stage','orderId'} or value['stage']!=expected[position]:
                        raise RuntimeError('Unexpected browser journey stage')
                    current=order_id(value['orderId'])
                    if created is not None and current!=created:raise RuntimeError('Browser journey order changed')
                    created=current
                    await stage(value['stage'],current)
                    child.stdin.write(b'{"ok":true}\n');await child.stdin.drain();position+=1
                else:
                    if position!=2 or set(value)!={'status','checks','orderId','cancelOrderId'} or value['status']!='passed':
                        raise RuntimeError('Incomplete browser journey')
                    if order_id(value['orderId'])!=created or order_id(value['cancelOrderId'])==created:
                        raise RuntimeError('Invalid browser journey result')
                    checks=value['checks']
                    if checks!=expected_checks:
                        raise RuntimeError('Invalid browser check identifiers')
                    if await asyncio.wait_for(child.wait(),timeout=20)!=0:raise RuntimeError('Browser driver exited unsuccessfully')
                    return value
        finally:
            # This dedicated process group contains only our Node/Chromium children.
            try:os.killpg(child.pid,signal.SIGTERM)
            except ProcessLookupError:pass
            if child.returncode is None:
                try:await asyncio.wait_for(child.wait(),timeout=8)
                except TimeoutError:
                    try:os.killpg(child.pid,signal.SIGKILL)
                    except ProcessLookupError:pass
                    await asyncio.wait_for(child.wait(),timeout=5)
