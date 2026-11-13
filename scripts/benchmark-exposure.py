#!/usr/bin/env python3
"""Warm sequential traversal benchmark; identical revisions, queries and limits."""
import json
import os
from pathlib import Path
import platform
import statistics
import sys
import time
import psycopg
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'specs/017-portfolio-lookthrough/generation/exposure-service'))
from engine import Engine

dsn=os.environ['EXPOSURE_TEST_DSN']
redis_url=os.environ['EXPOSURE_TEST_REDIS_URL']
report={'method':'Warm sequential, single client; 10 warmups + 100 timed requests/query/backend. Includes client round trip, traversal and path formatting. Both clients reuse established database connections. Reconciliation is measured separately from query latency.',
        'machine':{'cpuCount':os.cpu_count(),'python':platform.python_version(),'architecture':platform.machine()},
        'queries':[{'name':'known-concentration','account':70000,'target':'Z0G'},
                   {'name':'overlapping-funds','account':70020,'target':'E0'}], 'results':{},'initialProjectionSeconds':{}}
with psycopg.connect(dsn) as db:
    report['dataset'] = {
        'profile': db.execute('SELECT profile FROM exposure.metadata').fetchone()[0],
        'nodes': db.execute('SELECT count(*) FROM exposure.nodes').fetchone()[0],
        'referenceLinks': db.execute('SELECT count(*) FROM exposure.links').fetchone()[0],
        'positions': db.execute("SELECT count(*) FROM Positions WHERE accountid IN (SELECT substring(id from 2)::int FROM exposure.nodes WHERE kind='account') AND quantity<>0").fetchone()[0],
    }
report['unchangedSourceRefreshSeconds'] = {}
engines=[]
for backend in ('postgres','falkor'):
    start=time.perf_counter();e=Engine(dsn,backend,redis_url);engines.append(e)
    report['initialProjectionSeconds'][backend]=round(time.perf_counter()-start,3)
if engines[0].revision!=engines[1].revision: raise RuntimeError('Source changed during setup')
report['revision']=engines[0].revision
for engine in engines:
    report['results'][engine.backend]={}
    refresh_start=time.perf_counter()
    engine.refresh()
    report['unchangedSourceRefreshSeconds'][engine.backend]=round(time.perf_counter()-refresh_start,3)
    for query in report['queries']:
        engine.refresh()
        for _ in range(10): engine.exposure(query['account'],query['target'])
        values=[]
        for _ in range(100):
            # Refresh between groups keeps health current; never include reconciliation in query latency.
            if len(values)%20==0: engine.refresh()
            r=engine.exposure(query['account'],query['target']);values.append(r['elapsedMs'])
        ordered=sorted(values)
        report['results'][engine.backend][query['name']]={'samples':100,'medianMs':round(statistics.median(values),3),
            'p95Ms':ordered[94],'p99Ms':ordered[98],'pathCount':r['pathCount'],'fraction':r['totalFraction']}
for query in report['queries']:
    pg = report['results']['postgres'][query['name']]
    graph = report['results']['falkor'][query['name']]
    if pg['pathCount'] != graph['pathCount'] or abs(pg['fraction']-graph['fraction']) > 1e-9:
        raise RuntimeError('Benchmark backend results disagree')
print(json.dumps(report,indent=2))
if os.environ.get('EXPOSURE_BENCHMARK_OUTPUT'):
    Path(os.environ['EXPOSURE_BENCHMARK_OUTPUT']).write_text(json.dumps(report,indent=2)+'\n')
