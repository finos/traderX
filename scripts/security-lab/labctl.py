#!/usr/bin/env python3
"""Unified local account/identity lab workflow (currently macOS arm64)."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import platform
import shutil
import socket
import ssl
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[2]
SCRIPTS=Path(__file__).resolve().parent
DEFAULT=Path('/private/tmp/traderx-security-runtime')


def run(command,**kwargs):
    return subprocess.run(command,check=True,text=True,timeout=kwargs.pop('timeout',600),**kwargs)


def active(runtime):
    path=runtime/'browser-lab.json'
    if not path.exists():return None
    state=json.loads(path.read_text())
    if state.get('status') not in ('starting','ready'):return None
    result=subprocess.run(['ps','-p',str(state['pid']),'-o','lstart=','-o','command='],capture_output=True,text=True,timeout=5)
    return state if result.returncode==0 and result.stdout.strip()==state['process_identity'] else None


def doctor(runtime):
    checks={ 'supported_platform':sys.platform=='darwin' and platform.machine()=='arm64',
             'python_3_14':sys.version_info[:2]==(3,14)}
    checks.update({name:shutil.which(name) is not None for name in ('docker','git','openssl','security')})
    checks['identity_dependencies']=all(importlib.util.find_spec(name) is not None for name in ('jwt','cryptography'))
    pin=json.loads((ROOT/'specs/012-platform-convergence-c3/security-lab/baseline.lock.json').read_text())['generated_commit']
    checks['pinned_snapshot_available']=subprocess.run(['git','cat-file','-e',pin+':account-service'],cwd=ROOT,capture_output=True).returncode==0
    state=active(runtime)
    checks['browser_ports_available']=True
    if not state:
        for port in (18446,18447):
            try:
                with socket.socket() as probe:probe.bind(('127.0.0.1',port))
            except OSError:checks['browser_ports_available']=False
    checks['java_21']=False
    if sys.platform=='darwin':
        java_home=os.environ.get('JAVA_HOME')
        if not java_home:
            found=subprocess.run(['/usr/libexec/java_home','-v','21'],capture_output=True,text=True,timeout=10)
            java_home=found.stdout.strip() if found.returncode==0 else None
        if java_home:
            try:
                version=subprocess.run([str(Path(java_home)/'bin/java'),'-version'],capture_output=True,text=True,timeout=10)
                checks['java_21']=version.returncode==0 and ('"21.' in version.stderr or '"21"' in version.stderr)
            except OSError:pass
    if checks['docker']:
        from resource_preflight import check
        capacity=check(runtime,'fixture')
    else:capacity={'status':'blocked','reasons':['Docker CLI unavailable']}
    return {'status':'ready' if all(checks.values()) and capacity['status']=='ready' else 'blocked',
            'checks':checks,'capacity':capacity,'browser_lab':state['status'] if state else 'stopped',
            'tls_configured':(runtime/'browser-tls/cert.pem').exists(),
            'scope':'account/identity development only; macOS arm64, CPython 3.14; clean-machine acceptance pending'}


def validate_tls(tls):
    run(['openssl','x509','-in',str(tls/'cert.pem'),'-checkend','28800','-noout'],capture_output=True)
    cert=run(['openssl','x509','-in',str(tls/'cert.pem'),'-pubkey','-noout'],capture_output=True).stdout
    key=run(['openssl','pkey','-in',str(tls/'key.pem'),'-pubout'],capture_output=True).stdout
    if cert!=key:raise ValueError('TLS key does not match certificate')
    run(['security','verify-cert','-c',str(tls/'cert.pem'),'-p','ssl','-s','localhost'],capture_output=True)


def setup_tls(runtime,install_ca=False):
    tls=runtime/'browser-tls';tls.mkdir(mode=0o700,parents=True,exist_ok=True)
    if (tls/'cert.pem').exists():
        validate_tls(tls);return 'existing trusted certificate preserved'
    if not shutil.which('mkcert'):raise ValueError('Install mkcert (or provision approved cert.pem/key.pem/ca.pem) before setup')
    if install_ca:
        print('Installing a machine-local development CA with explicit --install-ca consent. Its trust is broader than localhost.',flush=True)
        run(['mkcert','-install'])
    ca=Path(run(['mkcert','-CAROOT'],capture_output=True).stdout.strip())
    if not (ca/'rootCA.pem').exists():raise ValueError('No development CA: rerun setup --install-ca after reviewing the trust change')
    run(['mkcert','-key-file',str(tls/'key.pem'),'-cert-file',str(tls/'cert.pem'),'localhost','127.0.0.1','::1'])
    shutil.copyfile(ca/'rootCA.pem',tls/'ca.pem')
    for name in ('key.pem','cert.pem','ca.pem'):(tls/name).chmod(0o600)
    validate_tls(tls);return 'development certificate generated; CA private key was not copied'


def verify_candidate(runtime):
    from account_dev import verify_files
    build=json.loads((runtime/'evidence/account-security-build.json').read_text())
    folder=runtime/'account-dev';verify_files(folder)
    if not json.loads((folder/'manifest.json').read_text()).get('identity_configured'):raise ValueError('Protected candidate required')
    if hashlib.sha256((folder/'candidate.jar').read_bytes()).hexdigest()!=build['jar_sha256']:raise ValueError('Candidate JAR drift')
    for name,digest in build['generation']['inputs'].items():
        if hashlib.sha256((ROOT/name).read_bytes()).hexdigest()!=digest:raise ValueError('Canonical source drift; rebuild in a fresh private build directory')


def stop(runtime):
    state=active(runtime)
    if state:
        run([sys.executable,str(SCRIPTS/'browser_lab.py'),'stop','--runtime-dir',str(runtime)])
        deadline=time.monotonic()+40
        while active(runtime):
            if time.monotonic()>deadline:raise TimeoutError('Graceful shutdown incomplete; no forced termination performed')
            time.sleep(.5)
    from resource_operation import operation_lock
    from account_dev import check_ownership,run_compose
    with operation_lock(runtime):
        check_ownership(runtime)
        if (runtime/'account-dev/manifest.json').exists():run_compose(runtime,runtime/'account-dev','stop')
    print('Local lab stopped; certificate, evidence and owned containers preserved. Synthetic tmpfs data resets on restart.')


def start(runtime,hours):
    state=active(runtime)
    if state:
        print('Lab '+state['status']+': '+state['url']);return
    verify_candidate(runtime);validate_tls(runtime/'browser-tls')
    from resource_operation import operation_lock
    from resource_preflight import require
    from account_dev import check_ownership,start_services
    with operation_lock(runtime) as fd:
        require(runtime,'fixture');check_ownership(runtime);start_services(runtime,runtime/'account-dev')
        log=runtime/'evidence/browser-launcher.log';log.parent.mkdir(exist_ok=True)
        with log.open('a') as stream:
            child=subprocess.Popen([sys.executable,str(SCRIPTS/'browser_lab.py'),'serve','--runtime-dir',str(runtime),'--hours',str(hours)],
                env=dict(os.environ,TRADERX_LAB_LOCK_FD=str(fd)),pass_fds=(fd,),start_new_session=True,stdin=subprocess.DEVNULL,stdout=stream,stderr=subprocess.STDOUT)
    deadline=time.monotonic()+300
    while time.monotonic()<deadline:
        state=active(runtime)
        if state and state['pid']==child.pid and state['status']=='ready':
            print('Ready: '+state['url']);print('Synthetic credentials: '+str(Path(state['private_directory'])/'users.json'));return
        if child.poll() is not None:raise RuntimeError('Startup failed; private diagnostics: '+str(log))
        time.sleep(1)
    raise TimeoutError('Startup still pending; inspect status/log before retrying')


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('action',choices=['doctor','setup','start','stop','reset','status'])
    parser.add_argument('--runtime-dir',type=Path,default=DEFAULT);parser.add_argument('--install-ca',action='store_true',help='Explicitly consent to mkcert installing a local development CA')
    parser.add_argument('--confirm-reset',action='store_true');parser.add_argument('--hours',type=float,default=4)
    args=parser.parse_args();runtime=args.runtime_dir.resolve();os.umask(0o077)
    if args.action=='doctor':
        result=doctor(runtime);print(json.dumps(result,indent=2));return 0 if result['status']=='ready' else 2
    if args.action=='status':
        state=active(runtime);print(json.dumps(state or {'status':'stopped'},indent=2));return 0
    if args.action=='stop':stop(runtime);return 0
    if args.action=='reset' and not args.confirm_reset:raise ValueError('Reset discards owned synthetic data; pass --confirm-reset explicitly')
    if not 0<args.hours<=8:raise ValueError('Duration must be within eight hours')
    if args.action=='setup':
        if active(runtime):
            verify_candidate(runtime);validate_tls(runtime/'browser-tls');print('Existing protected lab is configured and running; no changes made.');return 0
        result=doctor(runtime)
        if result['status']!='ready':print(json.dumps(result,indent=2));return 2
        from resource_operation import operation_lock
        from resource_preflight import require
        with operation_lock(runtime) as fd:
            require(runtime,'build');(runtime/'docker-client').mkdir(mode=0o700,parents=True,exist_ok=True)
            print(setup_tls(runtime,args.install_ca))
            env=dict(os.environ,TRADERX_LAB_LOCK_FD=str(fd));common=dict(env=env,pass_fds=(fd,),cwd=ROOT)
            if not (runtime/'evidence/account-security-build.json').exists():
                java_home=os.environ.get('JAVA_HOME') or run(['/usr/libexec/java_home','-v','21'],capture_output=True).stdout.strip()
                run([sys.executable,str(SCRIPTS/'build_account_security.py'),'--runtime-dir',str(runtime),'--java-home',java_home],**common)
            if not (runtime/'account-dev/manifest.json').exists():
                run([sys.executable,str(SCRIPTS/'verify_account_authorization.py'),'--runtime-dir',str(runtime)],timeout=900,**common)
            verify_candidate(runtime)
        print('Setup verified. Run traderx-lab start.');return 0
    if args.action=='reset':stop(runtime)
    start(runtime,args.hours)
    return 0

if __name__=='__main__':raise SystemExit(main())
