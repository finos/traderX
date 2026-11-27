import http.client
import threading
import unittest
from unittest.mock import patch
from urllib.parse import urlencode
import remote_gateway as gateway

class GatewayTests(unittest.TestCase):
    def setUp(self):
        self.server=gateway.ThreadingHTTPServer(('127.0.0.1',0),gateway.Handler);self.server.auth=gateway.Auth('a'*24);self.server.origin='https://lab.example';self.server.upstream=1
        self.thread=threading.Thread(target=self.server.serve_forever,daemon=True);self.thread.start()
    def tearDown(self):self.server.shutdown();self.server.server_close();self.thread.join()
    def request(self,path,body=None,extra=None):
        h={'Host':'lab.example','Origin':'https://lab.example','Content-Type':'application/x-www-form-urlencoded'};h.update(extra or {})
        c=http.client.HTTPConnection('127.0.0.1',self.server.server_address[1]);c.request('POST' if body is not None else 'GET',path,body,h);r=c.getresponse();result=r.status,dict(r.getheaders()),r.read();c.close();return result
    def test_gate_and_cookie(self):
        self.assertEqual(self.request('/')[0],303);self.assertEqual(self.request('/api/state')[0],401)
        self.assertNotIn('WWW-Authenticate',self.request('/login')[1])
        self.assertEqual(self.request('/login')[1]['Referrer-Policy'],'same-origin')
        self.assertEqual(self.request('/login','password=wrong')[0],401)
        status,h,_=self.request('/login',urlencode({'password':'a'*24}));self.assertEqual(status,303)
        for flag in ['Secure','HttpOnly','SameSite=Strict','Path=/']:self.assertIn(flag,h['Set-Cookie'])
        cookie=h['Set-Cookie'].split(';')[0]
        self.assertTrue(self.server.auth.valid(cookie))
        with patch.object(gateway.Handler,'forward',lambda handler,body=None:handler.send(200,b'forwarded')):
            self.assertEqual(self.request('/api/state',extra={'Cookie':cookie})[0],200)
            self.assertEqual(self.request('/api/runs','{}',{'Cookie':cookie,'Origin':'https://evil.example'})[0],403)
            self.assertEqual(self.request('/api/state',extra={'Cookie':cookie,'Host':'localhost'})[0],403)
        self.server.auth.sessions.clear();self.assertEqual(self.request('/api/state',extra={'Cookie':cookie})[0],401)
    def test_login_origin_and_rate_limit(self):
        self.assertEqual(self.request('/login','password='+'a'*24,{'Origin':'https://evil.example'})[0],403)
        for _ in range(10):self.assertEqual(self.request('/login','password=wrong')[0],401)
        self.assertEqual(self.request('/login','password='+'a'*24)[0],429)
