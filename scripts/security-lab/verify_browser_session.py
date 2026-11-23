"""Exercise HTTPS browser cookies and redirects against the real provider/session server."""
import http.cookiejar
import json
import urllib.request
import urllib.error
import urllib.parse
from browser_session import ORIGIN,SESSION
from identity_fixture import SUBJECTS,ISSUER
from verify_identity import NoRedirect,LoginForm


def verify(context,passwords,passed):
    jar=http.cookiejar.CookieJar()
    client=urllib.request.build_opener(urllib.request.ProxyHandler({}),urllib.request.HTTPSHandler(context=context),urllib.request.HTTPCookieProcessor(jar),NoRedirect())
    def request(url,body=None,headers=None):
        req=urllib.request.Request(url,data=body,headers=headers or {})
        try:
            with client.open(req,timeout=15) as r:return r.status,dict(r.headers),r.read()
        except urllib.error.HTTPError as r:return r.code,dict(r.headers),r.read()
    def expect(name,actual,wanted):
        if actual!=wanted:raise ValueError(name+': unexpected response')
        passed(name)
    expect('browser-anonymous-api-denied',request(ORIGIN+'/api/account/')[0],401)
    expect('browser-unsolicited-callback-denied',request(ORIGIN+'/callback?state=bad&code=bad')[0],400)
    request(ORIGIN+'/login')
    expect('browser-wrong-state-denied',request(ORIGIN+'/callback?state=bad&code=bad')[0],400)
    for name in SUBJECTS:
        # Each role represents a fresh browser profile. Local logout deliberately
        # does not clear the provider's SSO cookies or implement account switching.
        jar.clear()
        status,headers,_=request(ORIGIN+'/login')
        if status!=302 or not headers['Location'].startswith(ISSUER+'/protocol/openid-connect/auth?'):raise ValueError('Invalid provider redirect')
        status,_,html=request(headers['Location']);form=LoginForm(html.decode())
        if status!=200 or not form.action:raise ValueError('Provider login form missing')
        data=urllib.parse.urlencode(dict(username=name,password=passwords[name],credentialId='')).encode()
        status,headers,_=request(form.action,data)
        callback=headers.get('Location','')
        if status!=302 or not callback.startswith(ORIGIN+'/callback?'):raise ValueError('Invalid callback')
        status,headers,_=request(callback)
        expect(name+'-browser-code-callback',status,302)
        flags=headers.get('Set-Cookie','')
        if not all(x in flags for x in [SESSION+'=','Secure','HttpOnly','SameSite=Lax','Path=/']) or 'Domain=' in flags:raise ValueError('Unsafe session cookie')
        passed(name+'-browser-secure-cookie')
        expect(name+'-browser-callback-replay-denied',request(callback)[0],400)
        status,_,data=request(ORIGIN+'/session');session=json.loads(data)
        if status!=200 or session['subject']!=SUBJECTS[name] or 'token' in session:raise ValueError('Invalid browser identity')
        passed(name+'-browser-identity-without-token')
        status,_,data=request(ORIGIN+'/api/account/');rows=json.loads(data)
        expected={'reader':[22214],'trader':[62654],'operator':[]}[name]
        if status!=200 or sorted(r['id'] for r in rows)!=expected:raise ValueError('Browser scope mismatch')
        passed(name+'-browser-filtered-accounts')
        other=62654 if name=='reader' else 22214
        expect(name+'-browser-cross-account-denied',request(ORIGIN+'/api/account/'+str(other))[0],403)
        expect(name+'-browser-get-logout-denied',request(ORIGIN+'/logout')[0],404)
        expect(name+'-browser-missing-csrf-denied',request(ORIGIN+'/logout',b'',{'Origin':ORIGIN})[0],403)
        expect(name+'-browser-cross-origin-logout-denied',request(ORIGIN+'/logout',b'',{'Origin':'https://untrusted.invalid','X-CSRF-Token':session['csrf']})[0],403)
        old=next(c.value for c in jar if c.name==SESSION)
        expect(name+'-browser-logout',request(ORIGIN+'/logout',b'',{'Origin':ORIGIN,'X-CSRF-Token':session['csrf']})[0],200)
        expect(name+'-browser-logged-out-api-denied',request(ORIGIN+'/api/account/')[0],401)
        expect(name+'-browser-retired-session-denied',request(ORIGIN+'/api/account/',headers={'Cookie':SESSION+'='+old})[0],401)
