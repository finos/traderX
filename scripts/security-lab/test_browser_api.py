import json
import ssl
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from browser_api import ApiProxy, BoundaryError, MAX_BODY, MAX_RESPONSE, json_body, route


class BrowserApiTests(unittest.TestCase):
    def test_ambiguous_and_operator_routes_do_not_reach_backends(self):
        for path in ('https://evil.invalid/api/position-service/trades/',
                     '//api/position-service/trades/', '/api/position-service/../trades/',
                     '/api/position-service/%74rades/', '/api/position-service/trades/?accountId=1',
                     '/api/order-matcher/orders?accountId=1&accountId=2',
                     '/api/order-matcher/orders/open-count', '/api/order-matcher/actuator/health',
                     '/api/trade-service/tradeservice/order', '/api/position-service/trades/1#ignored',
                     '/api/position-service/trades/1\n'):
            with self.subTest(path=path), self.assertRaises(BoundaryError):
                route('GET', path)
        for method in ('PUT', 'DELETE', 'HEAD', 'OPTIONS'):
            with self.assertRaises(BoundaryError):route(method, '/api/order-matcher/orders')
        with self.assertRaises(BoundaryError):route('POST', '/api/order-matcher/orders/x/cancel?accountId=1')

    def test_named_api_routes_keep_the_account_in_the_backend_request(self):
        for method, target, service, path in (
            ('GET','/api/position-service/trades/22214','position-service','/trades/22214'),
            ('GET','/api/position-service/positions/','position-service','/positions/'),
            ('GET','/api/account-service/accountuser/','account-service','/accountuser/'),
            ('GET','/api/order-matcher/orders?accountId=62654','order-matcher','/orders?accountId=62654'),
            ('POST','/api/order-matcher/orders/abc-123/cancel','order-matcher','/orders/abc-123/cancel'),
            ('GET','/api/reference-data/stocks','reference-data','/stocks'),
            ('GET','/api/price-publisher/prices/IBM','price-publisher','/prices/IBM')):
            selected=route(method,target)
            self.assertEqual((selected.service,selected.path),(service,path))
        with self.assertRaises(BoundaryError):route('POST','/api/trade-service/trade/')

    def test_json_keeps_decimal_bytes_but_rejects_duplicate_keys_and_non_objects(self):
        raw=b'{"price": 99.1234567890123456789}'
        self.assertEqual(json_body(raw,'application/json; charset=utf-8'),raw)
        for body in (b'{"accountId":1,"accountId":2}', b'{"nested":{"a":1,"a":2}}',
                     b'[]', b'null', b'{"price":NaN}', b'\xff'):
            with self.assertRaises(BoundaryError):json_body(body,'application/json')
        with self.assertRaises(BoundaryError):json_body(b'{}','text/plain')
        with self.assertRaises(BoundaryError):json_body(b' '*(MAX_BODY+1),'application/json')

    def test_verified_transport_and_explicit_loopback_exception(self):
        for origin in ('http://localhost:80','http://example.invalid:80','https://x:443/path',
                       'https://user:password@x:443','https://x:443?query=1','https://x'):
            with self.assertRaises(ValueError):ApiProxy({'position-service':origin},loopback_fixture=True)
        with self.assertRaises(ValueError):ApiProxy({'position-service':'http://127.0.0.1:80'})
        with self.assertRaises(ValueError):ApiProxy({'position-service':'https://localhost:443'},ssl._create_unverified_context())
        with self.assertRaises(ValueError):ApiProxy({'caller-service':'https://localhost:443'})

    def test_recording_peer_sees_only_server_bearer_and_redirect_is_not_followed(self):
        seen=[]
        class Handler(BaseHTTPRequestHandler):
            def log_message(self,*args):pass
            def do_GET(self):
                seen.append((self.path,dict(self.headers)))
                code=302 if self.path.endswith('/2') else 200
                data=json.dumps([{'accountId':22214}]).encode()
                self.send_response(code)
                self.send_header('Location','/unexpected')
                self.send_header('Set-Cookie','upstream-secret=hidden')
                self.send_header('Content-Type','application/json')
                self.send_header('Content-Length',str(len(data)))
                self.end_headers();self.wfile.write(data)
        with ThreadingHTTPServer(('127.0.0.1',0),Handler) as server:
            thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
            try:
                proxy=ApiProxy({'position-service':f'http://127.0.0.1:{server.server_port}'},loopback_fixture=True)
                self.assertEqual(proxy.call('GET','/api/position-service/trades/22214','server-token'),(200,[{'accountId':22214}]))
                self.assertEqual(seen[0][0],'/trades/22214')
                self.assertEqual(seen[0][1]['Authorization'],'Bearer server-token')
                self.assertNotIn('Cookie',seen[0][1]);self.assertNotIn('X-Role',seen[0][1])
                with self.assertRaises(BoundaryError) as error:proxy.call('GET','/api/position-service/trades/2','server-token')
                self.assertEqual(error.exception.status,502)
                self.assertEqual(len(seen),2)
            finally:server.shutdown();thread.join()

    def test_upstream_failures_are_bounded_and_private_details_are_not_exposed(self):
        from unittest.mock import patch
        class Response:
            code=200
            headers=__import__('email.message',fromlist=['Message']).Message()
            headers['Content-Type']='application/json'
            def __enter__(self):return self
            def __exit__(self,*args):pass
            def read(self,limit):
                self.limit=limit
                return b'x'*(MAX_RESPONSE+1)
        proxy=ApiProxy({'position-service':'https://localhost:443'})
        response=Response()
        with patch.object(proxy.opener,'open',return_value=response):
            with self.assertRaises(BoundaryError) as error:proxy.call('GET','/api/position-service/trades/','private-token')
            self.assertEqual(error.exception.status,502);self.assertEqual(response.limit,MAX_RESPONSE+1)
            response.code=403
            self.assertEqual(proxy.call('GET','/api/position-service/trades/','private-token'),(403,{'error':'API request rejected'}))
        with patch.object(proxy.opener,'open',side_effect=ssl.SSLCertVerificationError('private certificate detail')):
            with self.assertRaises(BoundaryError) as error:proxy.call('GET','/api/position-service/trades/','private-token')
            self.assertNotIn('private',str(error.exception))


if __name__=='__main__':unittest.main()
