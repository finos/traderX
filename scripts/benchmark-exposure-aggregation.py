#!/usr/bin/env python3
"""Paired 2x2 experiment: database x full-path/aggregate strategy on one source."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import platform
import sys
import time
import psycopg
import redis as redis_client

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'specs/017-portfolio-lookthrough/generation/exposure-service'))
from dataset import seed_database
from impact_dataset import generate_impact
from engine import (Engine,IMPACT_SQL,IMPACT_AGGREGATE_SQL,IMPACT_EXPLANATIONS_SQL,
                    impact_cypher,aggregate_impact_cypher,impact_explanations_cypher)
spec=importlib.util.spec_from_file_location('impact_benchmark',Path(__file__).with_name('benchmark-exposure-impact.py'))
helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)


def measure_logical_payload(engine,method):
    """One untimed probe. JSON size of decoded DB values, NOT wire bytes."""
    results=[]
    if engine.redis:
        original=engine.query_graph
        def record(*args):
            result=original(*args);results.append(result);return result
        engine.query_graph=record
        try: output=method('IGROUP',20,3)
        finally: engine.query_graph=original
    else:
        original=engine.sql
        class Cursor:
            def __init__(self,cursor): self.cursor=cursor
            def fetchone(self):
                result=self.cursor.fetchone();results.append(result);return result
            def fetchall(self):
                result=self.cursor.fetchall();results.append(result);return result
        class Connection:
            def __getattr__(self,key): return getattr(original,key)
            def execute(self,*args): return Cursor(original.execute(*args))
        engine.sql=Connection()
        try: output=method('IGROUP',20,3)
        finally: engine.sql=original
    return output,{'queries':len(results),'logicalJsonBytes':sum(len(json.dumps(r,default=float,separators=(',',':')).encode()) for r in results)}


def assert_same_paths(left,right):
    if [r['accountId'] for r in left['portfolios']] != [r['accountId'] for r in right['portfolios']]:
        raise AssertionError('Rankings differ')
    for a,b in zip(left['portfolios'],right['portfolios']):
        if len(a['paths'])!=len(b['paths']): raise AssertionError('Explanation count differs')
        for p,q in zip(a['paths'],b['paths']):
            if p['nodes']!=q['nodes'] or abs(p['fraction']-q['fraction'])>1e-9:
                raise AssertionError('Explanation paths differ')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--accounts',type=int,default=1000)
    parser.add_argument('--layers',type=int,default=3)
    parser.add_argument('--samples',type=int,default=10)
    parser.add_argument('--rounds',type=int,default=4)
    parser.add_argument('--output',required=True)
    args=parser.parse_args()
    if args.samples<1 or args.rounds<1: parser.error('samples and rounds must be positive')
    dsn=os.environ['EXPOSURE_TEST_DSN'];redis=os.environ['EXPOSURE_TEST_REDIS_URL']
    data=generate_impact(args.accounts,args.layers);seed_database(dsn,data)
    variants=['postgres/paths','falkor/paths','postgres/aggregate','falkor/aggregate']
    report={'method':'Paired database x strategy experiment; four cyclically rotated condition orders, three warmups per condition/round, one client. Full totals and same top 20 portfolios / 3 paths. Refresh outside query timing. Logical payload probes outside timing; bytes are decoded values re-encoded as JSON, not protocol/wire bytes.',
            'fixture':{'accounts':args.accounts,'layers':args.layers,'profile':data['profile'],
                       'nodes':len(data['nodes']),'referenceLinks':len(data['links']),'positions':len(data['positions'])},
            'machine':{'python':platform.python_version(),'architecture':platform.machine(),'cpuCount':os.cpu_count()},
            'rawMs':{variant:[] for variant in variants},'rounds':[],'payload':{},'plans':{},'failures':[]}
    report['clients']={'psycopg':psycopg.__version__,'redis':redis_client.__version__,
                       'hiredisInstalled':importlib.util.find_spec('hiredis') is not None}
    sources=[Path(__file__),ROOT/'scripts/benchmark-exposure-impact.py',ROOT/'specs/017-portfolio-lookthrough/generation/exposure-service/engine.py',ROOT/'specs/017-portfolio-lookthrough/generation/exposure-service/impact_dataset.py']
    report['sourceFiles']={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}
    engines={}
    try:
        engines={backend:Engine(dsn,backend,redis) for backend in ('postgres','falkor')}
        if engines['postgres'].revision!=engines['falkor'].revision: raise AssertionError('Revisions differ')
        report['revision']=engines['postgres'].revision
        pg=engines['postgres'];pg.refresh();pg.impact('IGROUP')
        pg.sql.execute('ANALYZE exposure.projected_edges');pg.sql.execute('ANALYZE exposure.projected_nodes')
        expected=sorted((r for r in data['impactExpected'] if r['exposureValue']),key=lambda r:(-r['exposureValue'],r['accountId']))
        selected=[f"A{r['accountId']}" for r in expected[:20]]
        for name,query,params in [('paths',IMPACT_SQL,('IGROUP','IGROUP',12)),
                                  ('aggregate',IMPACT_AGGREGATE_SQL,('IGROUP',12,20)),
                                  ('explanations',IMPACT_EXPLANATIONS_SQL,(selected,12,'IGROUP',3))]:
            report['plans']['postgres/'+name]=pg.sql.execute('EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) '+query,params).fetchone()[0]
        graph=engines['falkor']
        for name,query in [('paths',impact_cypher('IGROUP')),('aggregate',aggregate_impact_cypher('IGROUP',20)),
                           ('explanations',impact_explanations_cypher('IGROUP',selected,3))]:
            report['plans']['falkor/'+name]=graph.redis.execute_command('GRAPH.EXPLAIN',graph.graph,query)
        reference=None
        for variant in variants:
            backend,strategy=variant.split('/');engine=engines[backend];engine.refresh()
            method=engine.impact if strategy=='aggregate' else engine.impact_paths
            result,payload=measure_logical_payload(engine,method)
            helper.check(result,data['impactExpected'],20)
            if reference: assert_same_paths(reference,result)
            else: reference=result
            report['payload'][variant]=payload
        report['result']={key:reference[key] for key in ('exposedPortfolioCount','totalExposureValue','pathCount')}
        for round_no in range(args.rounds):
            offset=round_no%len(variants);order=variants[offset:]+variants[:offset]
            round_result={'order':order,'results':{}}
            for variant in order:
                backend,strategy=variant.split('/');engine=engines[backend];engine.refresh()
                method=engine.impact if strategy=='aggregate' else engine.impact_paths
                for _ in range(3):
                    if time.time()-engine.last_checked>5: engine.refresh()
                    helper.check(method('IGROUP',20,3),data['impactExpected'],20)
                values=[]
                for _ in range(args.samples):
                    if time.time()-engine.last_checked>5: engine.refresh()
                    result=method('IGROUP',20,3);helper.check(result,data['impactExpected'],20)
                    assert_same_paths(reference,result)
                    values.append(result['elapsedMs'])
                report['rawMs'][variant].extend(values);round_result['results'][variant]=helper.summarize(values)
            report['rounds'].append(round_result)
            print(f'Completed {args.accounts} accounts / {args.layers} layers round {round_no+1}',flush=True)
        report['summary']={variant:helper.summarize(values) for variant,values in report['rawMs'].items()}
    except Exception as exc:
        report['failures'].append({'type':type(exc).__name__,'message':str(exc)});raise
    finally:
        Path(args.output).write_text(json.dumps(report,indent=2)+'\n')
        for engine in engines.values():
            if engine.sql: engine.sql.close()
            if engine.redis: engine.redis.close()
    print(json.dumps({'summary':report['summary'],'payload':report['payload']},indent=2))


if __name__=='__main__': main()
