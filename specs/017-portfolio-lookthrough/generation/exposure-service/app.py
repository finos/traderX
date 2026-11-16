"""Read-only demo service. Source mutations occur through TraderX or SQL fixtures."""
import json
import logging
import os
from pathlib import Path
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs
from dataset import generate, seed_database
from engine import Engine

STATIC=Path(__file__).with_name('static')


def make_handler(engine):
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            url=urlparse(self.path)
            try:
                if url.path in ('/','/exposure','/exposure/','/impact'):
                    body=(STATIC/('impact.html' if url.path=='/impact' else 'index.html')).read_bytes()
                    self.send_response(200); self.send_header('Content-Type','text/html; charset=utf-8')
                    self.end_headers(); self.wfile.write(body); return
                if url.path=='/health':
                    result=engine.status(); code=200 if result['healthy'] else 503
                elif url.path=='/api/catalog':
                    with engine.lock:
                        result={'accounts':sorted((n for n in engine.nodes.values() if n['kind']=='account'),
                                                  key=lambda n:int(n['id'][1:]))[:1000],
                                'targets':[n for n in engine.nodes.values() if n['kind']=='company'],
                                'status':engine.status()}
                    code=200
                elif url.path=='/api/impact':
                    q=parse_qs(url.query)
                    result=engine.impact(q.get('target',['Z0G'])[0],
                                         int(q.get('limit',['20'])[0]),
                                         int(q.get('pathLimit',['3'])[0]))
                    code=200
                elif url.path=='/api/exposure':
                    q=parse_qs(url.query)
                    result=engine.exposure(int(q.get('account',['70000'])[0]),q.get('target',['Z0G'])[0],
                                           max(1,min(1000,int(q.get('limit',['100'])[0]))))
                    code=200
                elif url.path=='/metrics':
                    status=engine.status()
                    body=f'exposure_projection_healthy {int(status["healthy"])}\nexposure_source_check_age_seconds {time.time()-engine.last_checked:.3f}\n'.encode()
                    self.send_response(200); self.send_header('Content-Type','text/plain; version=0.0.4')
                    self.end_headers(); self.wfile.write(body); return
                else:
                    result={'error':'Not found'}; code=404
            except KeyError:
                result={'error':'Unknown account or target'}; code=404
            except ValueError as exc:
                result={'error':str(exc)}; code=400
            except Exception:
                logging.exception('Exposure request failed')
                result={'error':'Projection unavailable; check /health'}; code=503
            self.send_response(code)
            self.send_header('Content-Type','application/json'); self.send_header('Cache-Control','no-store')
            self.end_headers(); self.wfile.write(json.dumps(result).encode())
    return Handler


if __name__=='__main__':
    logging.basicConfig(level=logging.INFO)
    dsn=os.environ.get('DATABASE_URL','postgresql://traderx:traderx@localhost:5432/traderx')
    seed_database(dsn,generate(os.environ.get('EXPOSURE_PROFILE','demo')))
    engine=Engine(dsn,os.environ.get('EXPOSURE_BACKEND','postgres'),os.environ.get('REDIS_URL','redis://falkordb:6379'))
    def synchronize():
        while True:
            time.sleep(2)
            try: engine.refresh()
            except Exception: logging.exception('Projection refresh failed; requests fail closed')
    threading.Thread(target=synchronize,daemon=True).start()
    ThreadingHTTPServer(('0.0.0.0',18120),make_handler(engine)).serve_forever()
