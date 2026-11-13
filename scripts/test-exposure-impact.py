#!/usr/bin/env python3
"""Real-database contract for firm-wide impact. Resets a disposable test database."""
import json
import os
from pathlib import Path
import sys
import threading
import unittest
from http.server import ThreadingHTTPServer
from urllib.error import HTTPError
from urllib.request import urlopen
import psycopg

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'specs/017-portfolio-lookthrough/generation/exposure-service'))
from dataset import seed_database
from impact_dataset import generate_impact
from engine import Engine
from app import make_handler
DSN=os.environ['EXPOSURE_TEST_DSN']
REDIS=os.environ['EXPOSURE_TEST_REDIS_URL']


def initialize_empty_schema(db):
    patch=(ROOT/'specs/005-postgres-database-replacement/generation/patches/0001-state-overlay.patch').read_text()
    section=patch.split('+++ b/postgres-database-replacement/postgres-init/initialSchema.sql\n',1)[1].split('\ndiff --git ',1)[0]
    db.execute('\n'.join(line[1:] for line in section.splitlines() if line.startswith('+')))
    db.execute('ALTER TABLE Positions ADD COLUMN IF NOT EXISTS averagecostbasis numeric(18,3)')


class ImpactIntegration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with psycopg.connect(DSN) as db:
            db.execute('DROP SCHEMA IF EXISTS exposure CASCADE; DROP SCHEMA public CASCADE; CREATE SCHEMA public')
            initialize_empty_schema(db)
        cls.data=generate_impact(1000,3)
        seed_database(DSN,cls.data)
        cls.engines=[Engine(DSN),Engine(DSN,'falkor',REDIS)]
        cls.expected=sorted((r for r in cls.data['impactExpected'] if r['exposureValue']),
                            key=lambda r:(-r['exposureValue'],r['accountId']))

    def setUp(self):
        for engine in self.engines: engine.refresh()

    @classmethod
    def tearDownClass(cls):
        for engine in cls.engines:
            if engine.sql: engine.sql.close()
            if engine.redis: engine.redis.close()

    def test_01_analytical_all_portfolios(self):
        for engine in self.engines:
            result=engine.impact('IGROUP',1000,100)
            self.assertEqual(result['exposedPortfolioCount'],750)
            self.assertAlmostEqual(result['totalExposureValue'],sum(r['exposureValue'] for r in self.expected),delta=.01)
            self.assertEqual(result['pathCount'],sum(r['pathCount'] for r in self.expected))
            self.assertEqual([r['accountId'] for r in result['portfolios']],[r['accountId'] for r in self.expected])
            for actual,expected in zip(result['portfolios'],self.expected):
                for field in ('portfolioValue','totalFraction','directFraction','exposureValue','pathCount'):
                    self.assertAlmostEqual(actual[field],expected[field])
                self.assertAlmostEqual(sum(p['fraction'] for p in actual['paths']),actual['totalFraction'])
                for path in actual['paths']:
                    self.assertEqual(path['nodes'][0]['id'],f"A{actual['accountId']}")
                    self.assertEqual(path['nodes'][-1]['id'],'IGROUP')

    def test_02_paths_and_limit_parity(self):
        results=[e.impact('IGROUP',10,3) for e in self.engines]
        for result in results:
            self.assertTrue(result['portfoliosTruncated'])
            self.assertEqual(result['exposedPortfolioCount'],750)
            self.assertEqual(len(result['portfolios']),10)
        for pg,graph in zip(*(r['portfolios'] for r in results)):
            self.assertEqual(pg['accountId'],graph['accountId'])
            self.assertEqual(pg['pathCount'],graph['pathCount'])
            self.assertEqual([[n['id'] for n in p['nodes']] for p in pg['paths']],
                             [[n['id'] for n in p['nodes']] for p in graph['paths']])
        for engine in self.engines:
            result=engine.impact('IGROUP',1,1)
            self.assertAlmostEqual(result['totalExposureValue'],sum(r['exposureValue'] for r in self.expected),delta=.01)
            self.assertEqual(len(result['portfolios']),1)
            self.assertEqual(engine.impact('IZERO')['portfolios'],[])

    def test_02b_database_aggregation_matches_full_path_baseline(self):
        for engine in self.engines:
            for limit,path_limit in ((1,1),(20,3),(1000,100)):
                baseline=engine.impact_paths('IGROUP',limit,path_limit)
                actual=engine.impact('IGROUP',limit,path_limit)
                for field in ('exposedPortfolioCount','pathCount','portfoliosTruncated'):
                    self.assertEqual(actual[field],baseline[field])
                self.assertAlmostEqual(actual['totalExposureValue'],baseline['totalExposureValue'],delta=.01)
                for row,reference in zip(actual['portfolios'],baseline['portfolios']):
                    self.assertEqual(row['accountId'],reference['accountId'])
                    self.assertEqual(row['pathCount'],reference['pathCount'])
                    self.assertEqual(row['pathsTruncated'],reference['pathsTruncated'])
                    for field in ('totalFraction','directFraction','indirectFraction'):
                        self.assertAlmostEqual(row[field],reference[field],delta=1e-9)
                    self.assertAlmostEqual(row['exposureValue'],reference['exposureValue'],delta=.01)
                    self.assertEqual(len(row['paths']),len(reference['paths']))
                    for path,want in zip(row['paths'],reference['paths']):
                        self.assertEqual(path['nodes'],want['nodes'])
                        self.assertAlmostEqual(path['fraction'],want['fraction'],delta=1e-9)

    def test_02c_graph_loss_during_either_phase_fails_closed_and_recovers(self):
        graph=self.engines[1]
        for phase in ('before_aggregate','before_explanations'):
            original=graph.query_graph
            calls=0
            def lose_graph(*args):
                nonlocal calls
                calls+=1
                if calls==(1 if phase=='before_aggregate' else 2):
                    graph.redis.execute_command('GRAPH.DELETE',graph.graph)
                return original(*args)
            graph.query_graph=lose_graph
            try:
                with self.assertRaises(RuntimeError): graph.impact('IGROUP')
                self.assertFalse(graph.status()['healthy'])
            finally:
                graph.query_graph=original
                graph.refresh()
            self.assertEqual(graph.impact('IGROUP')['exposedPortfolioCount'],750)

    def test_03_source_change_updates_ranking_and_total(self):
        original=sum(r['exposureValue'] for r in self.expected)
        with psycopg.connect(DSN) as db:
            db.execute('UPDATE Positions SET quantity=quantity*100 WHERE accountid=70000')
        try:
            for engine in self.engines:
                engine.refresh()
                result=engine.impact('IGROUP')
                self.assertEqual(result['portfolios'][0]['accountId'],70000)
                self.assertAlmostEqual(result['totalExposureValue'],original+9900000,delta=.01)
        finally:
            with psycopg.connect(DSN) as db:
                db.execute('UPDATE Positions SET quantity=quantity/100 WHERE accountid=70000')
            for engine in self.engines: engine.refresh()

    def test_04_shared_fund_update(self):
        with psycopg.connect(DSN) as db:
            db.execute("UPDATE exposure.links SET weight=.4 WHERE source LIKE 'IF2_%' AND target='IS0'")
            db.execute("UPDATE exposure.links SET weight=.4 WHERE source LIKE 'IF2_%' AND target='ICASH'")
        try:
            results=[]
            for engine in self.engines:
                engine.refresh()
                result=engine.impact('IGROUP',1000)
                by_id={r['accountId']:r for r in result['portfolios']}
                self.assertAlmostEqual(by_id[70001]['totalFraction'],.36)
                self.assertAlmostEqual(by_id[70002]['totalFraction'],.28)
                results.append(result['totalExposureValue'])
            self.assertAlmostEqual(*results,delta=.01)
        finally:
            with psycopg.connect(DSN) as db:
                db.execute("UPDATE exposure.links SET weight=.3 WHERE source LIKE 'IF2_%' AND target='IS0'")
                db.execute("UPDATE exposure.links SET weight=.5 WHERE source LIKE 'IF2_%' AND target='ICASH'")
            for engine in self.engines: engine.refresh()

    def test_05_http_errors_and_unavailability(self):
        for engine in self.engines:
            server=ThreadingHTTPServer(('127.0.0.1',0),make_handler(engine))
            threading.Thread(target=server.serve_forever,daemon=True).start()
            base=f'http://127.0.0.1:{server.server_port}/api/impact?'
            try:
                with urlopen(base+'target=IGROUP&limit=1&pathLimit=1') as response:
                    self.assertEqual(json.load(response)['exposedPortfolioCount'],750)
                for query,code in [('target=IS0',400),('target=IGROUP&limit=0',400),
                                   ('target=IGROUP&pathLimit=101',400),('target=%22%29DELETE',404)]:
                    with self.assertRaises(HTTPError) as caught: urlopen(base+query)
                    self.assertEqual(caught.exception.code,code)
                engine.error='test unavailable'
                with self.assertRaises(HTTPError) as caught: urlopen(base+'target=IGROUP')
                self.assertEqual(caught.exception.code,503)
            finally:
                engine.refresh();server.shutdown();server.server_close()
        graph=self.engines[1]
        graph.redis.execute_command('GRAPH.DELETE',graph.graph)
        with self.assertRaises(RuntimeError): graph.impact('IGROUP')
        graph.refresh()
        self.assertEqual(graph.impact('IGROUP')['exposedPortfolioCount'],750)


if __name__=='__main__': unittest.main(verbosity=2)
