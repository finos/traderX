#!/usr/bin/env python3
"""Real, isolated TLS OIDC authorization-code/PKCE compatibility experiment."""
import argparse
import base64
import fcntl
import hashlib
from html.parser import HTMLParser
import http.cookiejar
import json
import os
from pathlib import Path
import secrets
import ssl
import subprocess
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from datetime import datetime, timezone
import jwt
from resource_preflight import require as require_resources
from identity_fixture import IMAGE, BASE, ISSUER, CLIENT, AUDIENCE, REDIRECT, SUBJECTS, ROLES, TokenVerifier, accounts_for, realm

NAME = 'traderx-security-identity-fixture'
NETWORK = 'traderx-security-identity-check'
LABEL = 'traderx.security-lab.identity'


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl): return None


class LoginForm(HTMLParser):
    def __init__(self, html):
        super().__init__(); self.action = None; self.feed(html)
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'form' and attrs.get('id') == 'kc-form-login':
            self.action = attrs.get('action')


def main():
    global REDIRECT
    if not __debug__: raise RuntimeError('Run verification without Python optimization')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-dir', type=Path, default=Path('/private/tmp/traderx-security-runtime'))
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--sequential', action='store_true', help='Stop only the named C3 lab during this isolated fixture; restart it in finally')
    parser.add_argument('--account-api', action='store_true', help='Verify real tokens against the existing protected local account candidate')
    parser.add_argument('--browser-session', action='store_true', help='Also verify local HTTPS backend browser sessions')
    args = parser.parse_args(); runtime = args.runtime_dir.resolve()
    if args.browser_session:
        if not args.account_api: raise ValueError('Browser session requires --account-api')
        from browser_session import CALLBACK
        REDIRECT=CALLBACK
    os.umask(0o077)
    private = runtime / 'identity-fixture'; private.mkdir(mode=0o700, exist_ok=True)
    lock = (runtime / 'console-run.lock').open('a')
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    output = args.output_dir / 'identity-result.json'
    record = {'run_id': uuid.uuid4().hex, 'started_at': datetime.now(timezone.utc).isoformat(),
              'status': 'running', 'scope': 'isolated-provider-and-representative-verifier',
              'image': IMAGE, 'cases': [], 'limitations': [
                  'No live C3 account-service enforcement or browser session integration.',
                  'Development-mode disposable provider, not a production issuer deployment.',
                  'Provider signing-key rotation and refresh/logout integration remain pending.',
                  'A local PyJWT verifier is tested; Spring resource-server validation remains separate.']}
    output.write_text(json.dumps(record, indent=2)+'\n')
    docker = ['docker', '--config', str(runtime/'docker-client'), '--host', 'unix://'+str(Path.home()/'.docker/run/docker.sock')]
    def run(*cmd, required=True, timeout=180):
        result = subprocess.run(docker+list(cmd), capture_output=True, text=True, timeout=timeout)
        if required and result.returncode: raise RuntimeError('Docker fixture command failed: '+result.stderr)
        return result
    def remove(kind, name):
        result = run(kind, 'inspect', name, required=False)
        if result.returncode:
            if 'No such' not in result.stderr and 'not found' not in result.stderr:
                raise RuntimeError('Cannot inspect fixture ownership')
            return
        info = json.loads(result.stdout)[0]
        labels = info.get('Labels') if kind == 'network' else info['Config'].get('Labels')
        if (labels or {}).get(LABEL) != 'true': raise ValueError('Unrelated fixture name collision')
        run(*(['rm', '-f', name] if kind == 'container' else ['network', 'rm', name]))
    def passed(case):
        record['cases'].append({'id': case, 'status': 'passed'})
        print(case+': passed', flush=True)
    created = False; resume_lab = False
    try:
        remove('container', NAME); remove('network', NETWORK)
        if args.sequential:
            lab = json.loads(run('inspect', 'traderx-security-lab-control-plane').stdout)[0]
            if lab['Config'].get('Labels', {}).get('io.x-k8s.kind.cluster') != 'traderx-security-lab':
                raise ValueError('Unexpected lab container ownership')
            if lab['State']['Running']:
                if args.account_api: raise ValueError('Stop C3 before local account/provider integration')
                resume_lab = True
                run('stop', '-t', '30', 'traderx-security-lab-control-plane')
                record['lab_temporarily_stopped'] = True
        else:
            raise ValueError('Use --sequential on the current 6 GB host; concurrent provider acceptance is not established')
        record['resource_preflight'] = require_resources(runtime, 'fixture')
        if run('image', 'inspect', IMAGE, required=False).returncode: run('pull', IMAGE, timeout=300)
        info = json.loads(run('image', 'inspect', IMAGE).stdout)[0]
        record['image_config_id'] = info['Id']; record['architecture'] = info['Architecture']
        with tempfile.TemporaryDirectory(prefix='run-', dir=private) as temp:
            mount = Path(temp)/'provider'; mount.mkdir(mode=0o755)
            passwords = {name: secrets.token_urlsafe(32) for name in SUBJECTS}
            realm_config=realm(passwords)
            if args.account_api: realm_config['accessTokenLifespan']=900
            if args.browser_session: realm_config['clients'][0]['redirectUris']=[REDIRECT]
            (mount/'realm.json').write_text(json.dumps(realm_config)); (mount/'realm.json').chmod(0o644)
            subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes',
                            '-keyout', str(mount/'key.pem'), '-out', str(mount/'cert.pem'),
                            '-days', '1', '-subj', '/CN=localhost', '-addext',
                            'subjectAltName=DNS:localhost,IP:127.0.0.1'], capture_output=True, check=True, timeout=30)
            for name in ['key.pem', 'cert.pem']: (mount/name).chmod(0o644)
            context = ssl.create_default_context(cafile=str(mount/'cert.pem'))
            run('network', 'create', '--label', LABEL+'=true', NETWORK); created = True
            run('run', '-d', '--name', NAME, '--label', LABEL+'=true', '--network', NETWORK,
                '--user', '1000:1000', '--cap-drop=ALL', '--security-opt=no-new-privileges',
                '--memory', '640m', '--memory-swap', '640m', '--cpus', '1', '--pids-limit', '256',
                '-e', 'JAVA_OPTS_KC_HEAP=-Xms64m -Xmx256m',
                '--mount', f'type=bind,src={mount},dst=/lab,readonly',
                '--mount', f'type=bind,src={mount}/realm.json,dst=/opt/keycloak/data/import/realm.json,readonly',
                '-p', '127.0.0.1:18446:8443', IMAGE, 'start-dev', '--import-realm',
                '--hostname='+BASE, '--http-enabled=false',
                '--https-certificate-file=/lab/cert.pem', '--https-certificate-key-file=/lab/key.pem')
            def opener():
                return urllib.request.build_opener(urllib.request.ProxyHandler({}),
                    urllib.request.HTTPSHandler(context=context),
                    urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()), NoRedirect())
            def request(client, url, data=None):
                if urllib.parse.urlsplit(url).scheme != 'https' or urllib.parse.urlsplit(url).netloc != urllib.parse.urlsplit(BASE).netloc:
                    raise ValueError('Request outside fixed provider')
                req = urllib.request.Request(url, data=urllib.parse.urlencode(data).encode() if data is not None else None)
                try:
                    with client.open(req, timeout=10) as response:
                        return response.status, dict(response.headers), response.read()
                except urllib.error.HTTPError as error:
                    return error.code, dict(error.headers), error.read()
            deadline = time.monotonic()+120
            while True:
                try:
                    status, _, data = request(opener(), ISSUER+'/.well-known/openid-configuration')
                    if status == 200: break
                except (OSError, urllib.error.URLError): pass
                if time.monotonic() > deadline: raise TimeoutError('Provider readiness deadline')
                time.sleep(.5)
            discovery = json.loads(data)
            assert discovery['issuer'] == ISSUER
            endpoints = {name: ISSUER+'/protocol/openid-connect/'+suffix for name,suffix in
                         [('authorization_endpoint','auth'),('token_endpoint','token'),('jwks_uri','certs')]}
            for name, expected in endpoints.items(): assert discovery[name] == expected
            host = json.loads(run('inspect', NAME).stdout)[0]['HostConfig']
            assert host['CapDrop'] == ['ALL'] and host['PortBindings'] == {'8443/tcp': [{'HostIp':'127.0.0.1','HostPort':'18446'}]}
            passed('verified-tls-discovery-and-loopback-boundary')
            status, _, data = request(opener(), endpoints['jwks_uri']); assert status == 200
            verifier = TokenVerifier(json.loads(data))
            if args.account_api:
                from account_oidc import replace_trust, verify_user, database_fingerprint
                from verify_account_authorization import request as api_request
                record['scope']='real-provider-PKCE-to-local-Spring-account-API'
                record['limitations']=['Local candidate only; C3, browser sessions and other services unchanged.',
                    'Disposable development-mode provider; explicit process replacement, not automatic JWKS rotation.',
                    'Unexpired tokens remain usable offline until token or trust expiry; no immediate revocation.',
                    'Rotation-only access-token lifetime is 900 seconds; normal fixture lifetime remains 120 seconds.']
                previous_file=private/'previous-account-token.json'
                previous=json.loads(previous_file.read_text()) if previous_file.exists() and not args.browser_session else None
                public=replace_trust(runtime,json.loads(data))
                before=database_fingerprint(runtime)
                record['public_key_sha256']=hashlib.sha256(public).hexdigest()
                if previous:
                    if previous['public_key']==public.decode(): raise ValueError('Expected a newly generated provider key')
                    jwt.decode(previous['token'],previous['public_key'],algorithms=['RS256'],issuer=ISSUER,audience=AUDIENCE)
                    if api_request('GET','/account/',previous['token'])[0]!=401: raise ValueError('Retired key still accepted')
                    passed('unexpired-retired-provider-key-rejected-by-api')
            def begin(**changes):
                secret = secrets.token_urlsafe(48); state = secrets.token_urlsafe(24); nonce = secrets.token_urlsafe(24)
                challenge = base64.urlsafe_b64encode(hashlib.sha256(secret.encode()).digest()).decode().rstrip('=')
                params = dict(client_id=CLIENT, redirect_uri=REDIRECT, response_type='code', scope='openid',
                              state=state, nonce=nonce, code_challenge=challenge, code_challenge_method='S256')
                for key, value in changes.items():
                    if value is None: params.pop(key, None)
                    else: params[key] = value
                client = opener()
                response = request(client, endpoints['authorization_endpoint']+'?'+urllib.parse.urlencode(params))
                return client, secret, state, nonce, response
            def login(name, bad=False):
                client, secret, state, nonce, response = begin()
                assert response[0] == 200
                form = LoginForm(response[2].decode()); assert form.action
                response = request(client, form.action, dict(username=name,
                                   password='invalid-fixture-password' if bad else passwords[name], credentialId=''))
                if bad:
                    assert response[0] == 200 and LoginForm(response[2].decode()).action
                    return
                assert response[0] == 302
                target = urllib.parse.urlsplit(response[1]['Location'])
                assert urllib.parse.urlunsplit((target.scheme,target.netloc,target.path,'','')) == REDIRECT
                query = urllib.parse.parse_qs(target.query)
                assert query['state'] == [state] and 'error' not in query
                return query['code'][0], secret, nonce
            def exchange(code, secret):
                return request(opener(), endpoints['token_endpoint'], dict(grant_type='authorization_code',
                               client_id=CLIENT, redirect_uri=REDIRECT, code=code, code_verifier=secret))
            for name in SUBJECTS:
                code, secret, nonce = login(name)
                status, _, data = exchange(code, secret); assert status == 200
                tokens = json.loads(data)
                if args.account_api:
                    verify_user(name,tokens,passed)
                    if name=='reader': reader_token=tokens['access_token']
                claims = verifier.verify(tokens['access_token'])
                assert claims['sub'] == SUBJECTS[name]
                assert set(claims['realm_access']['roles']) & set(ROLES.values()) == {ROLES[name]}
                id_claims = TokenVerifier(json.loads(request(opener(), endpoints['jwks_uri'])[2]), audience=CLIENT).verify(tokens['id_token'])
                assert id_claims['nonce'] == nonce and id_claims['sub'] == claims['sub']
                assert accounts_for(claims) == ({22214} if name == 'reader' else {62654} if name == 'trader' else set())
                passed(name+'-code-pkce-signed-token-and-entitlements')
                try: verifier.verify(tokens['id_token'])
                except jwt.InvalidTokenError: pass
                else: raise AssertionError('Identity token accepted as API access token')
                passed(name+'-id-token-not-api-token')
                status, _, data = exchange(code, secret)
                assert status == 400 and json.loads(data)['error'] == 'invalid_grant'
                passed(name+'-code-reuse-denied')
                # Signature integrity: altered account claims cannot become trusted identity.
                pieces = tokens['access_token'].split('.')
                altered = {**claims, 'sub':'lab-operator'}
                pieces[1] = base64.urlsafe_b64encode(json.dumps(altered).encode()).decode().rstrip('=')
                try: verifier.verify('.'.join(pieces))
                except jwt.InvalidTokenError: pass
                else: raise AssertionError('Altered signed token accepted')
                passed(name+'-tampered-token-denied')
            login('reader', bad=True); passed('wrong-password-denied')
            code, secret, _ = login('reader')
            status, _, data = exchange(code, secrets.token_urlsafe(48))
            assert status == 400 and json.loads(data)['error'] == 'invalid_grant'
            passed('wrong-pkce-verifier-denied')
            for case, changes in [('missing-pkce-denied', dict(code_challenge=None, code_challenge_method=None)),
                                  ('alternate-redirect-denied', dict(redirect_uri='http://127.0.0.1:18447/other'))]:
                response = begin(**changes)[-1]
                # Provider may return an error to the approved callback; never a code/login form.
                assert response[0] in (400, 302)
                if response[0] == 302:
                    target = urllib.parse.urlsplit(response[1]['Location'])
                    assert urllib.parse.urlunsplit((target.scheme,target.netloc,target.path,'','')) == REDIRECT
                    query = urllib.parse.parse_qs(target.query)
                    assert 'error' in query and 'code' not in query
                passed(case)
            status, _, data = request(opener(), endpoints['token_endpoint'], dict(grant_type='password',
                client_id=CLIENT, username='reader', password=passwords['reader']))
            assert status == 400 and json.loads(data)['error'] == 'unauthorized_client'
            passed('password-grant-disabled')
            if args.account_api:
                if args.browser_session:
                    from browser_session import BrowserServer
                    from verify_browser_session import verify as verify_browser
                    server=BrowserServer(str(mount/'cert.pem'),str(mount/'key.pem'),context,json.loads(request(opener(),endpoints['jwks_uri'])[2])).start()
                    try: verify_browser(context,passwords,passed)
                    finally: server.close()
                    record['scope']='real-provider-and-local-browser-session-to-Spring-account-API'
                    record['limitations'][0]='Protocol-level HTTPS browser-cookie tests; no manual Chrome/Angular/C3 acceptance.'
                    record['limitations'].append('Local logout only; provider SSO and copied tokens are not revoked. No refresh-token flow.')
                if database_fingerprint(runtime)!=before: raise ValueError('HTTP campaign changed database state')
                passed('real-provider-api-database-unchanged')
                record['database_before_sha256']=before
                record['database_after_sha256']=database_fingerprint(runtime)
                run('stop','-t','10',NAME)
                if api_request('GET','/account/22214',reader_token)[0]!=200: raise ValueError('Unexpected offline verification behavior')
                passed('provider-outage-unexpired-token-within-trust-window')
                previous_file.write_text(json.dumps({'token':reader_token,'public_key':public.decode()}))
                previous_file.chmod(0o600)
            record['status'] = 'passed'
    except BaseException as error:
        record['status'] = 'failed'; record['failure_type'] = type(error).__name__
        raise
    finally:
        try:
            if created:
                remove('container', NAME); remove('network', NETWORK)
            record['cleanup'] = 'complete'
        except Exception:
            record['status'] = 'failed'; record['cleanup'] = 'failed'; raise
        finally:
            if resume_lab:
                try:
                    run('start', 'traderx-security-lab-control-plane')
                    record['lab_restart'] = 'started-readiness-requires-verification'
                except Exception:
                    record['lab_restart'] = 'failed'; record['status'] = 'failed'
            record['finished_at'] = datetime.now(timezone.utc).isoformat()
            record['source_sha256'] = {name: hashlib.sha256(Path(__file__).with_name(name).read_bytes()).hexdigest()
                                       for name in ['identity_fixture.py', 'verify_identity.py', 'requirements-identity.txt', 'resource_preflight.py']}
            if args.account_api:
                record['source_sha256']['account_oidc.py']=hashlib.sha256(Path(__file__).with_name('account_oidc.py').read_bytes()).hexdigest()
            if args.browser_session:
                for name in ('browser_session.py','verify_browser_session.py'):
                    record['source_sha256'][name]=hashlib.sha256(Path(__file__).with_name(name).read_bytes()).hexdigest()
            output.write_text(json.dumps(record, indent=2)+'\n')
    if record['status'] != 'passed': raise RuntimeError('Fixture or recovery did not pass')


if __name__ == '__main__': main()
