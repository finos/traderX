#!/usr/bin/env python3
"""Run equivalent typed investigation queries, with an independent path oracle."""
import argparse
import hashlib
import importlib.util
import psycopg
import redis
import json
import os
from pathlib import Path
import platform
import statistics
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT/'specs/017-portfolio-lookthrough/generation/exposure-service/dependency_probe.py'
sys.path.insert(0,str(MODULE.parent))
from dependency_probe import Probe, ROLES, SQL, fixture, oracle


def summary(values):
    return {'medianMs':statistics.median(values),'p95Ms':sorted(values)[max(0, int(len(values)*.95+.999)-1)]}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--accounts',type=int,default=1000)
    parser.add_argument('--banks',type=int,default=100)
    parser.add_argument('--samples',type=int,default=10)
    parser.add_argument('--rounds',type=int,default=4)
    parser.add_argument('--output',required=True)
    args=parser.parse_args()
    if args.samples<1 or args.rounds<2: parser.error('Require positive samples and at least two rounds')
    nodes,edges=fixture(args.accounts,args.banks)
    cases=[('all','B0000',None)]+[(r.lower(),'B0000',r) for r in ROLES]+[('absent','missing',None)]
    expected={name:oracle(nodes,edges,target,role) for name,target,role in cases}
    report={'fixture':{'accounts':args.accounts,'banks':args.banks,'nodes':len(nodes),'edges':len(edges)},
            'method':'Complete sorted typed paths, maximum eight edges, node-simple; forward Python oracle; one client, two warmups per condition, alternating backend order each round. Load outside timing. No amounts or loss simulation.',
            'machine':{'python':platform.python_version(),'architecture':platform.machine()},
            'sourceFiles':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [MODULE,Path(__file__)]},
            'clients':{'psycopg':psycopg.__version__,'redis':redis.__version__,'hiredisInstalled':importlib.util.find_spec('hiredis') is not None},
            'counts':{name:len(rows) for name,rows in expected.items()},'rawMs':{},'summary':{},'failures':[]}
    probe=None
    try:
        probe=Probe(os.environ['EXPOSURE_TEST_DSN'],os.environ['EXPOSURE_TEST_REDIS_URL'])
        probe.load(nodes,edges)
        report['plans']={'falkor':probe.redis.execute_command('GRAPH.EXPLAIN',probe.graph,probe.cypher('B0000',None)),
                         'postgres':probe.sql.execute('EXPLAIN (ANALYZE,BUFFERS,FORMAT JSON) '+SQL,('B0000',None,None)).fetchone()[0]}
        report['servers']={'postgres':probe.sql.execute('SELECT version()').fetchone()[0],
                           'redis':probe.redis.info('server')['redis_version'],
                           'modules':probe.redis.execute_command('MODULE','LIST')}
        for round_no in range(args.rounds):
            backends=('postgres','falkor') if round_no%2==0 else ('falkor','postgres')
            for name,target,role in cases:
                for backend in backends:
                    key=backend+'/'+name
                    for _ in range(2): assert probe.query(backend,target,role)==expected[name], key
                    values=report['rawMs'].setdefault(key,[])
                    for _ in range(args.samples):
                        start=time.perf_counter();actual=probe.query(backend,target,role)
                        elapsed=(time.perf_counter()-start)*1000
                        assert actual==expected[name],key
                        values.append(elapsed)
            print(f'Completed round {round_no+1}',flush=True)
        # Topology change: remove one guarantee and point it at another bank.
        old=next(e for e in edges if e[2]=='PARENT' and e[1]=='B0000' and e[0].endswith('_1'))
        changed=[e for e in edges if e!=old]+[(old[0],'B0001',old[2])]
        after=oracle(nodes,changed,'B0000')
        assert after!=expected['all'], 'Update must change the answer'
        probe.load(nodes,changed)
        for backend in ('postgres','falkor'): assert probe.query(backend,'B0000')==after,backend+' update'
        # Deliberate cycle with two valid paths: enforce node-simple semantics.
        tiny={'A':'portfolio','X':'company','Y':'company','B':'bank'}
        links=[('A','X','HOLDS'),('X','Y','PARENT'),('Y','X','PARENT'),('X','B','GUARANTEED_BY'),('Y','B','COUNTERPARTY')]
        wanted=[(('A','X','B'),('HOLDS','GUARANTEED_BY')),(('A','X','Y','B'),('HOLDS','PARENT','COUNTERPARTY'))]
        assert oracle(tiny,links,'B')==wanted
        probe.load(tiny,links)
        for backend in ('postgres','falkor'): assert probe.query(backend,'B')==wanted,backend+' cycles'
        report['checks']={'allSamplesMatchOracle':True,'relationshipUpdate':True,'cycleFixture':True,'absentTarget':True}
        report['summary']={key:summary(values) for key,values in report['rawMs'].items()}
    except Exception as exc:
        report['failures'].append({'type':type(exc).__name__,'message':str(exc)})
        raise
    finally:
        Path(args.output).write_text(json.dumps(report,indent=2)+'\n')
        if probe: probe.close()
    print(json.dumps({'counts':report['counts'],'summary':report['summary']},indent=2))

if __name__=='__main__': main()
