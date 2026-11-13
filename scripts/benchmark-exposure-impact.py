#!/usr/bin/env python3
"""Firm-wide impact pilot with analytical answers and alternating backend order.

EXPOSURE_TEST_DSN must point at a fresh TraderX-initialized database per fixture.
No schema/data are reset by this script. Timings include full path enumeration,
shared aggregation/ranking and bounded response formatting, not HTTP or seeding.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import statistics
import sys
import time
import threading
import psycopg

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'specs/017-portfolio-lookthrough/generation/exposure-service'))
from dataset import seed_database
from impact_dataset import generate_impact
from engine import Engine, IMPACT_SQL, impact_cypher


def check(result,expected,limit):
    ordered=sorted((r for r in expected if r['exposureValue']),key=lambda r:(-r['exposureValue'],r['accountId']))
    if result['exposedPortfolioCount']!=len(ordered): raise AssertionError('Exposed count differs')
    if abs(result['totalExposureValue']-sum(r['exposureValue'] for r in ordered))>0.01:
        raise AssertionError('Total exposure differs')
    if result['pathCount']!=sum(r['pathCount'] for r in ordered): raise AssertionError('Path count differs')
    if [r['accountId'] for r in result['portfolios']] != [r['accountId'] for r in ordered[:limit]]:
        raise AssertionError('Ranking differs')
    for actual,want in zip(result['portfolios'],ordered):
        for field in ('portfolioValue','exposureValue','totalFraction','directFraction','pathCount'):
            tolerance=.01 if field.endswith('Value') else 1e-9
            if abs(actual[field]-want[field])>tolerance: raise AssertionError(f'{field} differs')


def summarize(values):
    ordered=sorted(values)
    return {'samples':len(values),'medianMs':round(statistics.median(values),3),
            'p95Ms':ordered[max(0,int(len(values)*.95+.999)-1)],
            'p99Ms':ordered[max(0,int(len(values)*.99+.999)-1)]}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--accounts',type=int,default=1000)
    parser.add_argument('--layers',type=int,default=2)
    parser.add_argument('--samples',type=int,default=20)
    parser.add_argument('--rounds',type=int,default=3)
    parser.add_argument('--output',required=True)
    args=parser.parse_args()
    if args.samples<1 or args.rounds<1: parser.error('samples/rounds must be positive')
    dsn=os.environ['EXPOSURE_TEST_DSN'];redis=os.environ['EXPOSURE_TEST_REDIS_URL']
    data=generate_impact(args.accounts,args.layers)
    started=time.perf_counter();seed_database(dsn,data)
    report={'task':'Firm-wide corporate-group impact, ranked monetary exposure and top fund paths',
            'method':'One reverse traversal per backend. Indexed recursive SQL versus Cypher; identical shared aggregation and ranking. Three warmups each round, alternating backend order. No concurrent clients. Source refresh outside query timing.',
            'machine':{'architecture':platform.machine(),'python':platform.python_version(),'cpuCount':os.cpu_count()},
            'fixture':{'profile':data['profile'],'accounts':args.accounts,'layers':args.layers,
                       'nodes':len(data['nodes']),'referenceLinks':len(data['links']),'positions':len(data['positions'])},
            'seedSeconds':round(time.perf_counter()-started,3),
            'initialProjectionSeconds':{},'unchangedRefreshSeconds':{},'rounds':[],
            'failures':[],'rawMs':{'postgres':[],'falkor':[]}}
    report['sourceFiles']={str(path.relative_to(ROOT)):hashlib.sha256(path.read_bytes()).hexdigest()
                           for path in (Path(__file__),ROOT/'specs/017-portfolio-lookthrough/generation/exposure-service/engine.py',ROOT/'specs/017-portfolio-lookthrough/generation/exposure-service/impact_dataset.py')}
    engines={}
    try:
        for backend in ('postgres','falkor'):
            started=time.perf_counter();engines[backend]=Engine(dsn,backend,redis)
            report['initialProjectionSeconds'][backend]=round(time.perf_counter()-started,3)
        if len({e.revision for e in engines.values()})!=1: raise AssertionError('Source revisions differ')
        report['revision']=engines['postgres'].revision
        # Same reverse edge index and fresh statistics for SQL before timing.
        pg=engines['postgres'];pg.refresh();pg.impact('IGROUP')
        pg.sql.execute('ANALYZE exposure.projected_edges');pg.sql.execute('ANALYZE exposure.projected_nodes')
        report['postgresPlan']=pg.sql.execute('EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) '+IMPACT_SQL,
                                             ('IGROUP','IGROUP',12)).fetchone()[0]
        graph=engines['falkor']
        report['falkorPlan']=graph.redis.execute_command('GRAPH.EXPLAIN',graph.graph,impact_cypher('IGROUP'))
        for round_no in range(args.rounds):
            order=['postgres','falkor'] if round_no%2==0 else ['falkor','postgres']
            round_result={'order':order,'results':{}}
            for backend in order:
                engine=engines[backend]
                started=time.perf_counter();engine.refresh()
                report['unchangedRefreshSeconds'].setdefault(backend,[]).append(round(time.perf_counter()-started,3))
                for _ in range(3): check(engine.impact('IGROUP',20,3),data['impactExpected'],20)
                values=[]
                for _ in range(args.samples):
                    # Avoid classifying the deliberate freshness deadline as a query failure.
                    if time.time()-engine.last_checked>5: engine.refresh()
                    result=engine.impact('IGROUP',20,3)
                    check(result,data['impactExpected'],20)
                    values.append(result['elapsedMs'])
                report['rawMs'][backend].extend(values)
                round_result['results'][backend]=summarize(values)
                report['result']={'exposedPortfolios':result['exposedPortfolioCount'],
                                  'totalExposureValue':result['totalExposureValue'],'paths':result['pathCount'],
                                  'returnedPortfolios':len(result['portfolios']),'pathsPerReturnedPortfolio':3}
            report['rounds'].append(round_result)
        report['summary']={backend:summarize(values) for backend,values in report['rawMs'].items()}
        report['sharedFundUpdate']={}
        fund_pattern=f'IF{args.layers-1}_%'
        updated=[]
        for index,row in enumerate(data['impactExpected']):
            item=dict(row)
            item['totalFraction']=(1,.36,.28,0)[index%4]
            item['exposureValue']=item['portfolioValue']*item['totalFraction']
            updated.append(item)
        for engine in engines.values(): engine.refresh()
        with psycopg.connect(dsn) as db:
            db.execute("UPDATE exposure.links SET weight=.4 WHERE source LIKE %s AND target='IS0'",(fund_pattern,))
            db.execute("UPDATE exposure.links SET weight=.4 WHERE source LIKE %s AND target='ICASH'",(fund_pattern,))
        try:
            for backend,engine in engines.items():
                # Observe the real last source check; do not reset the freshness clock.
                started=time.perf_counter();errors=[]
                def refresh():
                    try: engine.refresh()
                    except Exception as exc: errors.append(exc)
                worker=threading.Thread(target=refresh);worker.start()
                unhealthy=0.0;max_age=0.0;previous=time.perf_counter()
                while worker.is_alive():
                    now=time.perf_counter();status=engine.status()
                    max_age=max(max_age,time.time()-status['sourceCheckedAt'])
                    if not status['healthy']: unhealthy+=now-previous
                    previous=now;worker.join(.01)
                if errors: raise errors[0]
                elapsed=time.perf_counter()-started
                check(engine.impact('IGROUP',20,3),updated,20)
                report['sharedFundUpdate'][backend]={'refreshSeconds':round(elapsed,3),
                    'observedUnhealthySeconds':round(unhealthy,3),'maxSourceCheckAgeSeconds':round(max_age,3)}
        finally:
            with psycopg.connect(dsn) as db:
                db.execute("UPDATE exposure.links SET weight=.3 WHERE source LIKE %s AND target='IS0'",(fund_pattern,))
                db.execute("UPDATE exposure.links SET weight=.5 WHERE source LIKE %s AND target='ICASH'",(fund_pattern,))

    except Exception as exc:
        report['failures'].append({'type':type(exc).__name__,'message':str(exc)})
        raise
    finally:
        Path(args.output).write_text(json.dumps(report,indent=2)+'\n')
        for engine in engines.values():
            if engine.sql: engine.sql.close()
            if engine.redis: engine.redis.close()
    print(json.dumps({key:report[key] for key in ('fixture','result','summary','initialProjectionSeconds')},indent=2))


if __name__=='__main__': main()
