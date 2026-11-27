#!/usr/bin/env python3
"""Temporary cookie-authenticated loopback gateway for the experiment console."""
import argparse
from collections import deque
from http.cookies import SimpleCookie, CookieError
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import http.client
import json
from pathlib import Path
import secrets
import threading
import time
from urllib.parse import parse_qs,urlsplit
from console import public_origin

COOKIE='__Host-traderx_lab'
PAGE=b'''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>TraderX Lab sign in</title><style>body{font:18px system-ui;background:#f3f6fb;color:#18283f;margin:0;padding:32px}main{max-width:420px;margin:8vh auto;background:white;padding:28px;border-radius:16px}input,button{box-sizing:border-box;width:100%;font:inherit;padding:14px;margin:12px 0;border-radius:6px;border:1px solid #9daecc}button{background:#245aad;color:white}p{line-height:1.5}</style><main><h1>TraderX Security Lab</h1><p>Enter your lab access code. No username is needed.</p><form method="post" action="/login"><label for="password">Access code</label><input id="password" name="password" type="password" autocomplete="current-password" required autofocus><button>Sign in</button></form><p>Temporary access to synthetic experiments.</p></main></html>'''

class Auth:
    def __init__(self,password):
        if len(password)<20:raise ValueError('Access code must have at least 20 characters')
        self.password=password;self.sessions={};self.failures=deque();self.lock=threading.Lock()
    def login(self,password):
        with self.lock:
            now=time.monotonic()
            while self.failures and self.failures[0]<now-60:self.failures.popleft()
            if len(self.failures)>=10:return 429,None
            if not secrets.compare_digest(password.encode(),self.password.encode()):
                self.failures.append(now);return 401,None
            self.sessions={s:expiry for s,expiry in self.sessions.items() if expiry>now}
            token=secrets.token_urlsafe(32);self.sessions[token]=now+28800
            return 303,token
    def valid(self,header):
        try:
            cookies=SimpleCookie();cookies.load(header or '')
            token=cookies[COOKIE].value if COOKIE in cookies else ''
        except CookieError:return False
        with self.lock:return self.sessions.get(token,0)>time.monotonic()

class Handler(BaseHTTPRequestHandler):
    def log_message(self,*_):pass
    def send(self,status,body=b'',headers=None):
        self.send_response(status)
        for k,v in {'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store','Referrer-Policy':'same-origin','X-Content-Type-Options':'nosniff','Content-Security-Policy':"default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; frame-ancestors 'none'; base-uri 'none'",**(headers or {})}.items():self.send_header(k,v)
        self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
    def host_ok(self):return self.headers.get_all('Host')==[urlsplit(self.server.origin).netloc]
    def do_GET(self):
        if not self.host_ok():return self.send(403,b'Host rejected')
        if self.path=='/login':return self.send(200,PAGE)
        if not self.server.auth.valid(self.headers.get('Cookie')):
            return self.send(401,b'Sign in required') if self.path.startswith('/api/') else self.send(303,headers={'Location':'/login'})
        self.forward()
    def do_POST(self):
        if not self.host_ok() or self.headers.get('Origin')!=self.server.origin:
            return self.send(403,b'Origin rejected')
        if self.headers.get('Transfer-Encoding'):return self.send(400,b'Unsupported request framing')
        try:
            if len(self.headers.get_all('Content-Length',[]))!=1:raise ValueError()
            size=int(self.headers['Content-Length'])
            if not 0<size<=1024:raise ValueError()
        except ValueError:return self.send(400,b'Invalid request size')
        body=self.rfile.read(size)
        if self.path=='/login':
            if self.headers.get('Content-Type')!='application/x-www-form-urlencoded':return self.send(415,b'Form required')
            try:
                fields=parse_qs(body.decode(),strict_parsing=True,max_num_fields=2)
                if set(fields)!={'password'} or len(fields['password'])!=1:raise ValueError()
            except (ValueError,UnicodeDecodeError):return self.send(400,b'Invalid form')
            status,token=self.server.auth.login(fields['password'][0])
            if token:return self.send(303,headers={'Location':'/','Set-Cookie':f'{COOKIE}={token}; Path=/; Secure; HttpOnly; SameSite=Strict; Max-Age=28800'})
            return self.send(status,b'Access code not accepted. Use Back to retry.' if status==401 else b'Too many attempts. Wait one minute, then use Back to retry.')
        if not self.server.auth.valid(self.headers.get('Cookie')):return self.send(401,b'Sign in required')
        self.forward(body)
    def forward(self,body=None):
        if not self.path.startswith('/') or self.path.startswith('//'):return self.send(400,b'Invalid path')
        headers={k:self.headers[k] for k in ['Host','Origin','Content-Type','X-Lab-CSRF'] if k in self.headers}
        conn=http.client.HTTPConnection('127.0.0.1',self.server.upstream,timeout=35)
        try:
            conn.request(self.command,self.path,body,headers);response=conn.getresponse();data=response.read()
            self.send_response(response.status)
            for k,v in response.getheaders():
                if k.lower() not in ['connection','transfer-encoding','server','date','set-cookie','www-authenticate']:self.send_header(k,v)
            self.end_headers();self.wfile.write(data)
        except (OSError,http.client.HTTPException):self.send(502,b'Lab console unavailable. Try again shortly.')
        finally:conn.close()

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--origin',required=True,type=public_origin);parser.add_argument('--credential-file',required=True,type=Path);parser.add_argument('--port',type=int,default=18082);parser.add_argument('--upstream',type=int,default=18081)
    args=parser.parse_args();auth=Auth(json.loads(args.credential_file.read_text())['password'])
    server=ThreadingHTTPServer(('127.0.0.1',args.port),Handler);server.auth=auth;server.origin=args.origin;server.upstream=args.upstream
    print('Authenticated lab gateway ready on loopback port '+str(args.port),flush=True);server.serve_forever()

if __name__=='__main__':main()
