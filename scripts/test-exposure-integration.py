#!/usr/bin/env python3
"""Integration contract against disposable real PostgreSQL and FalkorDB instances."""
import json
import os
from pathlib import Path
import statistics
import sys
import threading
import time
import unittest
from urllib.request import urlopen
from urllib.error import HTTPError
import psycopg

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'specs/017-portfolio-lookthrough/generation/exposure-service'))
from dataset import generate, seed_database
from engine import Engine, validate
from app import make_handler
from http.server import ThreadingHTTPServer

DSN=os.environ['EXPOSURE_TEST_DSN']
REDIS=os.environ['EXPOSURE_TEST_REDIS_URL']


class ExposureIntegration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with psycopg.connect(DSN) as db:
            # Dedicated test database only, with the actual inherited SQL schema.
            db.execute('DROP SCHEMA IF EXISTS exposure CASCADE')
            db.execute('DROP SCHEMA public CASCADE; CREATE SCHEMA public')
            patch=(ROOT/'specs/005-postgres-database-replacement/generation/patches/0001-state-overlay.patch').read_text()
            section=patch.split('+++ b/postgres-database-replacement/postgres-init/initialSchema.sql\n',1)[1].split('\ndiff --git ',1)[0]
            schema='\n'.join(line[1:] for line in section.splitlines() if line.startswith('+'))
            db.execute(schema)
            db.execute('ALTER TABLE Positions ADD COLUMN IF NOT EXISTS averagecostbasis numeric(18,3)')
        cls.data=generate(os.environ.get('EXPOSURE_TEST_PROFILE','small'))
        seed_database(DSN,cls.data)
        cls.pg=Engine(DSN)
        cls.graph=Engine(DSN,'falkor',REDIS)

    def test_01_twenty_independent_scenarios(self):
        for expected in self.data['scenarios']:
            for engine in (self.pg,self.graph):
                result=engine.exposure(expected['accountId'],expected['target'])
                self.assertAlmostEqual(result['totalFraction'],.14)
                self.assertAlmostEqual(result['directFraction'],.02)
                self.assertAlmostEqual(result['indirectFraction'],.12)
                self.assertEqual(result['pathCount'],2)
                self.assertAlmostEqual(result['exposureValue'],14000)
                self.assertEqual(len(engine.exposure(expected['accountId'],expected['target'],1)['paths']),1)

    def test_02_arbitrary_portfolio_parity(self):
        for account,target in [(70020,'E0'),(70021,'E4'),(70029,'E8'),(70000,'E0')]:
            p=self.pg.exposure(account,target)
            g=self.graph.exposure(account,target)
            self.assertAlmostEqual(p['totalFraction'],g['totalFraction'])
            self.assertEqual(p['pathCount'],g['pathCount'])
            self.assertEqual(p['revision'],g['revision'])

    def test_03_position_change_and_restart(self):
        old=self.pg.revision
        with psycopg.connect(DSN) as db:
            db.execute("UPDATE Positions SET quantity=40 WHERE accountid=70000 AND security='Z0S'")
        for engine in (self.pg,self.graph):
            engine.refresh()
            self.assertNotEqual(old,engine.revision)
            self.assertAlmostEqual(engine.exposure(70000,'Z0G')['totalFraction'],16000/102000)
        seed_database(DSN,self.data)  # must not undo a live booking
        restarted=Engine(DSN,'falkor',REDIS)
        self.assertAlmostEqual(restarted.exposure(70000,'Z0G')['totalFraction'],16000/102000)
        with psycopg.connect(DSN) as db:
            db.execute("UPDATE Positions SET quantity=20 WHERE accountid=70000 AND security='Z0S'")
        for engine in (self.pg,self.graph): engine.refresh()

    def test_03b_proportional_position_change(self):
        old = self.pg.revision
        try:
            with psycopg.connect(DSN) as db:
                db.execute("UPDATE Positions SET quantity=quantity*2 WHERE accountid=70000")
            for engine in (self.pg,self.graph):
                engine.refresh()
                result = engine.exposure(70000,'Z0G')
                self.assertNotEqual(old,result['revision'])
                self.assertAlmostEqual(result['totalFraction'],.14)
                self.assertAlmostEqual(result['portfolioValue'],200000)
                self.assertAlmostEqual(result['exposureValue'],28000)
        finally:
            with psycopg.connect(DSN) as db:
                db.execute("UPDATE Positions SET quantity=quantity/2 WHERE accountid=70000")
            for engine in (self.pg,self.graph): engine.refresh()

    def test_04_allocation_change(self):
        with psycopg.connect(DSN) as db:
            db.execute("UPDATE exposure.links SET weight=.25 WHERE source='Z0N' AND target='Z0S'")
            db.execute("UPDATE exposure.links SET weight=.75 WHERE source='Z0N' AND target='Z0C'")
        for engine in (self.pg,self.graph):
            engine.refresh()
            self.assertAlmostEqual(engine.exposure(70000,'Z0G')['totalFraction'],.08)
        with psycopg.connect(DSN) as db:
            db.execute("UPDATE exposure.links SET weight=.5 WHERE source='Z0N'")
        for engine in (self.pg,self.graph): engine.refresh()

    def test_05_graph_loss_and_recovery(self):
        self.graph.redis.execute_command('GRAPH.DELETE',self.graph.graph)
        with self.assertRaises(RuntimeError): self.graph.exposure(70000,'Z0G')
        self.graph.refresh()
        self.assertAlmostEqual(self.graph.exposure(70000,'Z0G')['totalFraction'],.14)
        healthy=self.graph.redis
        from redis import Redis
        self.graph.redis=Redis.from_url('redis://127.0.0.1:1',socket_connect_timeout=.1)
        with self.assertRaises(Exception): self.graph.refresh()
        with self.assertRaises(RuntimeError): self.graph.exposure(70000,'Z0G')
        self.graph.redis=healthy
        self.graph.refresh()

    def test_06_invalid_source_fails_closed(self):
        with psycopg.connect(DSN) as db:
            db.execute("UPDATE Positions SET quantity=-1 WHERE accountid=70000 AND security='Z0S'")
        for engine in (self.pg,self.graph):
            with self.assertRaises(ValueError): engine.refresh()
            with self.assertRaises(RuntimeError): engine.exposure(70000,'Z0G')
        with psycopg.connect(DSN) as db:
            db.execute("UPDATE Positions SET quantity=20 WHERE accountid=70000 AND security='Z0S'")
        for engine in (self.pg,self.graph): engine.refresh()
        conflicting='demo' if self.data['profile']=='small' else 'small'
        with self.assertRaises(ValueError): seed_database(DSN,generate(conflicting))
        with self.assertRaises(ValueError): validate([('X','X','company',100)],[('X','X',1)])
        with self.assertRaises(ValueError):
            validate([('F','F','fund',100),('S','S','security',100)],[('F','S',.5)])
        with self.assertRaises(ValueError):
            validate([(f'N{i}','Node','company',100) for i in range(14)],
                     [(f'N{i}',f'N{i+1}',1) for i in range(13)])

    def test_07_http_contract_and_injection(self):
        for engine in (self.pg,self.graph):
            server=ThreadingHTTPServer(('127.0.0.1',0),make_handler(engine))
            thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
            base=f'http://127.0.0.1:{server.server_port}'
            try:
                with urlopen(base+'/api/exposure?account=70000&target=Z0G') as response:
                    self.assertAlmostEqual(json.load(response)['totalFraction'],.14)
                for query,code in [('account=nope',400),('target=%22%7D%29%20DETACH%20DELETE%20n',404),('account=0',404)]:
                    with self.assertRaises(HTTPError) as caught: urlopen(base+'/api/exposure?'+query)
                    self.assertEqual(caught.exception.code,code)
                engine.nodes['A100000']={'id':'A100000','name':'Large-profile account','kind':'account'}
                with urlopen(base+'/api/catalog') as response:
                    accounts=json.load(response)['accounts']
                    self.assertEqual(accounts[0]['id'],'A70000')
                engine.nodes.pop('A100000')
                with urlopen(base+'/') as response: self.assertIn(b'What do I really own?',response.read())
                self.assertAlmostEqual(engine.exposure(70000,'Z0G')['totalFraction'],.14)
            finally: server.shutdown();server.server_close()

    def test_08_benchmark_report(self):
        report={'profile':self.data['profile'],'nodes':len(self.data['nodes']),'referenceLinks':len(self.data['links']),
                'positions':len(self.data['positions']),'revision':self.pg.revision,'results':{}}
        for engine in (self.pg,self.graph):
            times=[engine.exposure(70000,'Z0G')['elapsedMs'] for _ in range(20)]
            report['results'][engine.backend]={'medianMs':statistics.median(times),'p95Ms':sorted(times)[18]}
        print('\nBENCHMARK '+json.dumps(report))
        if os.environ.get('EXPOSURE_TEST_REPORT'):
            Path(os.environ['EXPOSURE_TEST_REPORT']).write_text(json.dumps(report,indent=2)+'\n')


if __name__=='__main__': unittest.main(verbosity=2)
