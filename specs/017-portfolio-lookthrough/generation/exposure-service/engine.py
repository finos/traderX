"""Consistent snapshot projections with real SQL/Cypher variable-depth traversal."""
import hashlib
import json
import threading
import time
import uuid
from datetime import datetime, timezone
import psycopg
from redis import Redis

MAX_DEPTH = 12


def validate(nodes, edges):
    kinds={r[0]:r[2] for r in nodes}
    adjacent={n:[] for n in kinds}
    for source,target,weight in edges:
        if source not in kinds or target not in kinds or not 0 < weight <= 1:
            raise ValueError('Invalid link endpoint or allocation weight')
        adjacent[source].append((target,weight))
    depths={}
    active=set()
    def visit(node):
        if node in active: raise ValueError('Cyclic exposure relationships')
        if node in depths: return depths[node]
        active.add(node)
        depth=max((1+visit(t) for t,_ in adjacent[node]),default=0)
        active.remove(node)
        if depth > MAX_DEPTH: raise ValueError('Exposure depth exceeds supported bound')
        if kinds[node]=='fund' and abs(sum(w for _,w in adjacent[node])-1)>1e-8:
            raise ValueError('Fund allocations must sum to one')
        if kinds[node] in ('company','security'):
            if len(adjacent[node])>1 or any(kinds[t]!='company' or w!=1 for t,w in adjacent[node]):
                raise ValueError('Issuance and corporate parent relationships must be a single unweighted chain')
        if kinds[node]=='fund' and any(kinds[t] not in ('fund','security') for t,_ in adjacent[node]):
            raise ValueError('Funds must hold securities or other funds')
        depths[node]=depth
        return depth
    for node in kinds: visit(node)


def source_snapshot(dsn):
    with psycopg.connect(dsn) as db:
        db.execute('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY')
        nodes = db.execute('SELECT id,name,kind,mark::float8 FROM exposure.nodes ORDER BY id').fetchall()
        links = db.execute('SELECT source,target,weight::float8 FROM exposure.links ORDER BY source,target').fetchall()
        holdings = db.execute('''SELECT p.accountid,p.security,p.quantity::float8,n.mark::float8
            FROM Positions p LEFT JOIN exposure.nodes n ON n.id=p.security
            WHERE p.accountid IN (SELECT substring(id from 2)::int FROM exposure.nodes WHERE kind='account')
            AND p.quantity<>0 ORDER BY p.accountid,p.security''').fetchall()
        as_of = db.execute('SELECT as_of FROM exposure.metadata').fetchone()[0]
    if any(q < 0 or mark is None for _,_,q,mark in holdings):
        raise ValueError('Exposure requires long-only holdings with known valuation marks')
    totals = {}
    for a,_,q,mark in holdings: totals[a]=totals.get(a,0)+q*mark
    edges = list(links)
    for a,s,q,mark in holdings: edges.append((f'A{a}',s,q*mark/totals[a]))
    validate(nodes,edges)
    encoded=json.dumps([nodes,edges,as_of,totals],separators=(',',':')).encode()
    return nodes,edges,hashlib.sha256(encoded).hexdigest(),as_of,totals


class Engine:
    def __init__(self, dsn, backend='postgres', redis_url='redis://localhost:6379/0'):
        if backend not in ('postgres','falkor'): raise ValueError('Unknown backend')
        self.dsn,self.backend=dsn,backend
        self.redis=Redis.from_url(redis_url,decode_responses=True,socket_timeout=30) if backend=='falkor' else None
        self.lock=threading.RLock()
        self.revision=None
        self.graph=None
        self.last_checked=0
        self.error='Starting'
        self.nodes={}
        self.totals={}
        self.sql=None
        with psycopg.connect(dsn) as db:
            db.execute('''CREATE TABLE IF NOT EXISTS exposure.projected_edges (
                source text NOT NULL,target text NOT NULL,weight float8 NOT NULL,
                PRIMARY KEY(source,target))''')
        self.refresh()

    def query_graph(self, graph, query):
        result=self.redis.execute_command('GRAPH.QUERY',graph,query,'TIMEOUT',10000,'--compact')
        def decode(value):
            kind,data=value
            if kind==6: return [decode(v) for v in data]
            if kind==5: return float(data)
            return data
        return [[decode(v) for v in row] for row in result[1]] if len(result)>2 else []

    def refresh(self):
        try:
            nodes,edges,revision,as_of,totals=source_snapshot(self.dsn)
            # Detect data loss after a FalkorDB restart even if source is unchanged.
            graph_alive = self.redis.exists(self.graph) if self.redis and self.graph else True
            if revision != self.revision or not graph_alive:
                graph='exposure_'+revision[:24]+'_'+uuid.uuid4().hex[:12]
                if self.redis:
                    if self.redis.exists(graph): self.redis.execute_command('GRAPH.DELETE',graph)
                    self.query_graph(graph,'CREATE INDEX FOR (n:Entity) ON (n.id)')
                    for start in range(0,len(nodes),500):
                        batch=[{'id':r[0]} for r in nodes[start:start+500]]
                        literal='['+','.join('{id:'+json.dumps(r['id'])+'}' for r in batch)+']'
                        self.query_graph(graph,f'UNWIND {literal} AS row CREATE (:Entity {{id:row.id}})')
                    for start in range(0,len(edges),500):
                        literal='['+','.join('{s:'+json.dumps(s)+',t:'+json.dumps(t)+',w:'+str(w)+'}'
                                             for s,t,w in edges[start:start+500])+']'
                        self.query_graph(graph,f'UNWIND {literal} AS row MATCH (s:Entity {{id:row.s}}), '
                                         '(t:Entity {id:row.t}) CREATE (s)-[:EXPOSURE {weight:row.w}]->(t)')
                with self.lock:
                    if not self.redis:
                        with psycopg.connect(self.dsn) as db:
                            db.execute('DELETE FROM exposure.projected_edges')
                            with db.cursor() as cur:
                                with cur.copy('COPY exposure.projected_edges FROM STDIN') as copy:
                                    for row in edges: copy.write_row(row)
                    old=self.graph
                    self.graph=graph
                    self.nodes={r[0]:{'id':r[0],'name':r[1],'kind':r[2]} for r in nodes}
                    self.totals=totals
                    self.revision=revision
                    self.as_of=as_of
                    self.projected_at=datetime.now(timezone.utc).isoformat()
                    if self.redis and old and old != graph and self.redis.exists(old):
                        self.redis.execute_command('GRAPH.DELETE',old)
            with self.lock:
                self.last_checked=time.time()
                self.error=None
        except Exception as exc:
            with self.lock: self.error=type(exc).__name__+': '+str(exc)
            raise

    def status(self):
        return {'backend':self.backend,'revision':self.revision,'valuationAsOf':getattr(self,'as_of',None),
                'projectedAt':getattr(self,'projected_at',None),
                'sourceCheckedAt':self.last_checked,'healthy':self.error is None and time.time()-self.last_checked<15,
                'error':self.error}

    def exposure(self, account, target, limit=100):
        start=time.perf_counter()
        with self.lock:
            if not self.status()['healthy']: raise RuntimeError('Projection unavailable or stale')
            source=f'A{account}'
            if source not in self.nodes or target not in self.nodes: raise KeyError('Unknown account or target')
            if self.nodes[target]['kind']!='company': raise ValueError('Target must be a corporate entity')
            if self.redis:
                # A missing graph must not become a successful empty exposure query.
                if not self.redis.exists(self.graph):
                    raise RuntimeError('Projection graph is missing; wait for reconciliation')
                # IDs are JSON-escaped literals, never interpolated raw Cypher input.
                rows=self.query_graph(self.graph,
                    f'MATCH p=(a:Entity {{id:{json.dumps(source)}}})-[:EXPOSURE*1..{MAX_DEPTH}]->'
                    f'(t:Entity {{id:{json.dumps(target)}}}) '
                    'RETURN [n IN nodes(p) | n.id], reduce(w=1.0, r IN relationships(p) | w*r.weight)')
            else:
                if self.sql is None or self.sql.closed:
                    self.sql=psycopg.connect(self.dsn,autocommit=True)
                    self.sql.execute("SET statement_timeout='10s'")
                rows=self.sql.execute('''WITH RECURSIVE walk(node,path,weight,depth) AS (
                      SELECT %s::text,ARRAY[%s::text],1.0::float8,0
                      UNION ALL SELECT e.target,w.path||e.target,w.weight*e.weight,w.depth+1
                      FROM walk w JOIN exposure.projected_edges e ON e.source=w.node
                      WHERE w.depth<%s AND NOT e.target=ANY(w.path)
                    ) SELECT path,weight FROM walk WHERE node=%s AND depth>0''',
                                      (source,source,MAX_DEPTH,target)).fetchall()
            rows=sorted(rows,key=lambda r:(-float(r[1]),r[0]))
            total=sum(float(r[1]) for r in rows)
            direct=sum(float(w) for path,w in rows if not any(self.nodes[n]['kind']=='fund' for n in path))
            return {**self.status(),'accountId':account,'target':target,'totalFraction':total,
                    'directFraction':direct,'indirectFraction':total-direct,
                    'portfolioValue':self.totals.get(account,0),'exposureValue':self.totals.get(account,0)*total,
                    'pathCount':len(rows),'pathsTruncated':len(rows)>limit,
                    'paths':[{'nodes':[self.nodes[n] for n in path],'fraction':float(weight)} for path,weight in rows[:limit]],
                    'elapsedMs':round((time.perf_counter()-start)*1000,3)}
