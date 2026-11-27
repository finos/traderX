#!/usr/bin/env python3
"""Verify account switching with one retained HTTPS cookie jar and provider confirmation."""
import argparse
from html.parser import HTMLParser
import http.cookiejar
import json
from pathlib import Path
import ssl
import urllib.error
import urllib.parse
import urllib.request
from account_oidc import database_fingerprint
from browser_session import ORIGIN,SESSION
from identity_fixture import ISSUER,SUBJECTS
from verify_identity import NoRedirect,LoginForm

class LogoutForm(HTMLParser):
    def __init__(self,html):self.action=None;self.values={};super().__init__();self.feed(html)
    def handle_starttag(self,tag,attrs):
        attrs=dict(attrs)
        if tag=='form':self.action=attrs.get('action')
        if tag in ('input','button') and attrs.get('name'):self.values[attrs['name']]=attrs.get('value','')


def verify(context,passwords,passed):
    jar=http.cookiejar.CookieJar()
    client=urllib.request.build_opener(urllib.request.ProxyHandler({}),urllib.request.HTTPSHandler(context=context),urllib.request.HTTPCookieProcessor(jar),NoRedirect())
    def request(url,data=None,headers=None):
        if urllib.parse.urlsplit(url).netloc not in ('localhost:18446','localhost:18447') or not url.startswith('https://'):raise ValueError('Unexpected destination')
        req=urllib.request.Request(url,data=data,headers=headers or {})
        try:
            with client.open(req,timeout=15) as r:return r.status,dict(r.headers),r.read()
        except urllib.error.HTTPError as r:return r.code,dict(r.headers),r.read()
    def expect(name,actual,wanted):
        if actual!=wanted:raise ValueError(name+': unexpected status '+str(actual))
        passed(name)
    for name in ('reader','trader','operator'):
        status,headers,_=request(ORIGIN+'/login')
        if status!=302:raise ValueError('Login redirect missing')
        status,_,html=request(headers['Location']);form=LoginForm(html.decode())
        if status!=200 or not form.action:raise ValueError('Fresh login form missing')
        status,headers,_=request(form.action,urllib.parse.urlencode(dict(username=name,password=passwords[name],credentialId='')).encode())
        if status!=302:raise ValueError('Account-switch login failed: '+str(status))
        expect(name+'-shared-profile-login',request(headers['Location'])[0],302)
        status,_,data=request(ORIGIN+'/session');session=json.loads(data)
        if status!=200 or session['subject']!=SUBJECTS[name]:raise ValueError('Wrong shared-profile identity')
        passed(name+'-shared-profile-identity')
        status,_,data=request(ORIGIN+'/api/account/');expected={'reader':[22214],'trader':[62654],'operator':[]}[name]
        if status!=200 or sorted(r['id'] for r in json.loads(data))!=expected:raise ValueError('Scope changed during switch')
        passed(name+'-shared-profile-account-scope')
        expect(name+'-switch-missing-csrf-denied',request(ORIGIN+'/switch',b'',{'Origin':ORIGIN})[0],403)
        expect(name+'-switch-cross-origin-denied',request(ORIGIN+'/switch',b'',{'Origin':'https://untrusted.invalid','X-CSRF-Token':session['csrf']})[0],403)
        old=next(c.value for c in jar if c.name==SESSION)
        status,_,data=request(ORIGIN+'/switch',b'',{'Origin':ORIGIN,'X-CSRF-Token':session['csrf']})
        expect(name+'-switch-local-session-ended',status,200)
        expect(name+'-switch-old-cookie-denied',request(ORIGIN+'/session',headers={'Cookie':SESSION+'='+old})[0],401)
        status,_,html=request(json.loads(data)['redirect']);form=LogoutForm(html.decode())
        if status!=200 or not form.action:raise ValueError('Provider confirmation form missing')
        status,headers,body=request(urllib.parse.urljoin(ISSUER+'/',form.action),urllib.parse.urlencode(form.values).encode())
        if status not in (200,302):raise ValueError('Provider logout confirmation failed')
        if status==302 and headers.get('Location')!=ORIGIN+'/':raise ValueError('Unexpected logout return')
        if status==200 and b'logged out' not in body.lower():raise ValueError('Provider logout unconfirmed')
        passed(name+'-provider-logout-confirmed')


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--runtime-dir',type=Path,default=Path('/private/tmp/traderx-security-runtime'));args=parser.parse_args();runtime=args.runtime_dir
    state=json.loads((runtime/'browser-lab.json').read_text())
    if state['status']!='ready':raise ValueError('Persistent browser lab must be ready')
    private=Path(state['private_directory']);ca=runtime/'browser-tls/ca.pem'
    context=ssl.create_default_context(cafile=str(ca if ca.exists() else private/'provider/cert.pem'))
    before=database_fingerprint(runtime);record={'status':'running','scope':'same-cookie-jar-provider-confirmed-account-switch','cases':[]}
    output=runtime/'evidence/browser-switch.json'
    def passed(name):record['cases'].append(name);print(name+': passed',flush=True)
    try:
        verify(context,json.loads((private/'users.json').read_text()),passed)
        after=database_fingerprint(runtime)
        if before!=after:raise ValueError('Database changed')
        record.update(status='passed',before_sha256=before,after_sha256=after)
    except BaseException as error:record.update(status='failed',failure_type=type(error).__name__);raise
    finally:output.write_text(json.dumps(record,indent=2)+'\n')

if __name__=='__main__':main()
