"""Consistent snapshot projections with real SQL/Cypher variable-depth traversal."""
import hashlib
import json
import math
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
        if not self.redis:
            with psycopg.connect(dsn) as db:
                db.execute('''CREATE TABLE IF NOT EXISTS exposure.projected_edges (
                    source text NOT NULL,target text NOT NULL,weight float8 NOT NULL,
                    PRIMARY KEY(source,target))''')
                db.execute('CREATE INDEX IF NOT EXISTS exposure_edges_target ON exposure.projected_edges(target)')
                db.execute('CREATE TABLE IF NOT EXISTS exposure.projected_nodes (id text PRIMARY KEY,kind text NOT NULL)')
                db.execute('ALTER TABLE exposure.projected_nodes ADD COLUMN IF NOT EXISTS portfolio_value float8 NOT NULL DEFAULT 0')
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
                        batch=[{'id':r[0],'kind':r[2],'value':totals.get(int(r[0][1:]),0) if r[2]=='account' else 0} for r in nodes[start:start+500]]
                        literal='['+','.join('{id:'+json.dumps(r['id'])+',kind:'+json.dumps(r['kind'])+',value:'+str(r['value'])+'}' for r in batch)+']'
                        self.query_graph(graph,f'UNWIND {literal} AS row CREATE (:Entity {{id:row.id,kind:row.kind,value:row.value}})')
                    for start in range(0,len(edges),500):
                        literal='['+','.join('{s:'+json.dumps(s)+',t:'+json.dumps(t)+',w:'+str(w)+'}'
                                             for s,t,w in edges[start:start+500])+']'
                        self.query_graph(graph,f'UNWIND {literal} AS row MATCH (s:Entity {{id:row.s}}), '
                                         '(t:Entity {id:row.t}) CREATE (s)-[:EXPOSURE {weight:row.w}]->(t)')
                with self.lock:
                    if not self.redis:
                        with psycopg.connect(self.dsn) as db:
                            db.execute('DELETE FROM exposure.projected_edges')
                            db.execute('DELETE FROM exposure.projected_nodes')
                            with db.cursor() as cur:
                                with cur.copy('COPY exposure.projected_nodes (id,kind,portfolio_value) FROM STDIN') as copy:
                                    for row in nodes:
                                        value=totals.get(int(row[0][1:]),0) if row[2]=='account' else 0
                                        copy.write_row((row[0],row[2],value))
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
                'sourceCheckedAt':self.last_checked,'healthy':self.revision is not None and self.error is None and time.time()-self.last_checked<15,
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
                    'RETURN collect([[n IN nodes(p) | n.id], reduce(w=1.0, r IN relationships(p) | w*r.weight)])')[0][0]
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

    def impact_paths(self, target, limit=20, path_limit=3):
        """One reverse traversal for the whole book, followed by shared aggregation.

        Limits bound the returned ranking/explanations, never the totals.
        Both backends enumerate economic paths, including shared fund routes.
        """
        start=time.perf_counter()
        if not 1 <= limit <= 1000 or not 1 <= path_limit <= 100:
            raise ValueError('Invalid impact result limit')
        with self.lock:
            if not self.status()['healthy']: raise RuntimeError('Projection unavailable or stale')
            if target not in self.nodes: raise KeyError('Unknown target')
            if self.nodes[target]['kind']!='company': raise ValueError('Target must be a corporate entity')
            if self.redis:
                if not self.redis.exists(self.graph): raise RuntimeError('Projection graph is missing')
                rows=self.query_graph(self.graph,impact_cypher(target))[0][0]
                rows=[(list(reversed(path)),weight) for path,weight in rows]
            else:
                if self.sql is None or self.sql.closed:
                    self.sql=psycopg.connect(self.dsn,autocommit=True)
                    self.sql.execute("SET statement_timeout='10s'")
                rows=self.sql.execute(IMPACT_SQL,(target,target,MAX_DEPTH)).fetchall()
            grouped={}
            for path,weight in rows:
                account=int(path[0][1:])
                grouped.setdefault(account,[]).append((path,float(weight)))
            portfolios=[]
            for account,paths in grouped.items():
                paths.sort(key=lambda r:(-r[1],r[0]))
                fraction=sum(weight for _,weight in paths)
                direct=sum(weight for path,weight in paths
                           if not any(self.nodes[node]['kind']=='fund' for node in path))
                value=self.totals[account]
                portfolios.append({'accountId':account,'name':self.nodes[f'A{account}']['name'],
                    'portfolioValue':value,'exposureValue':value*fraction,'totalFraction':fraction,
                    'directFraction':direct,'indirectFraction':fraction-direct,'pathCount':len(paths),
                    'pathsTruncated':len(paths)>path_limit,
                    'paths':[{'nodes':[self.nodes[node] for node in path],
                              'fraction':weight,'exposureValue':value*weight}
                             for path,weight in paths[:path_limit]]})
            # Round only the ranking key to cents so floating reduction order cannot
            # change tie ordering across databases. Preserve full response precision.
            portfolios.sort(key=lambda r:(-math.floor(r['exposureValue']*100+0.5),r['accountId']))
            return {**self.status(),'target':target,'exposedPortfolioCount':len(portfolios),
                    'totalExposureValue':sum(row['exposureValue'] for row in portfolios),
                    'pathCount':len(rows),'portfoliosTruncated':len(portfolios)>limit,
                    'portfolios':portfolios[:limit],
                    'elapsedMs':round((time.perf_counter()-start)*1000,3)}


    def impact(self, target, limit=20, path_limit=3):
        """Aggregate/rank in the database, then fetch bounded selected explanations."""
        start=time.perf_counter()
        if not 1 <= limit <= 1000 or not 1 <= path_limit <= 100:
            raise ValueError('Invalid impact result limit')
        with self.lock:
            if not self.status()['healthy']: raise RuntimeError('Projection unavailable or stale')
            if target not in self.nodes: raise KeyError('Unknown target')
            if self.nodes[target]['kind']!='company': raise ValueError('Target must be a corporate entity')
            if self.redis:
                if not self.redis.exists(self.graph): raise RuntimeError('Projection graph is missing')
                result=self.query_graph(self.graph,aggregate_impact_cypher(target,limit))
                if not result:
                    self.revision=None;self.error='Projection target disappeared during aggregation'
                    raise RuntimeError(self.error)
                count,total,path_count,ranked=result[0]
            else:
                if self.sql is None or self.sql.closed:
                    self.sql=psycopg.connect(self.dsn,autocommit=True)
                    self.sql.execute("SET statement_timeout='10s'")
                count,total,path_count,ranked=self.sql.execute(IMPACT_AGGREGATE_SQL,
                    (target,MAX_DEPTH,limit)).fetchone()
            selected=[row[0] for row in ranked]
            explanations={account:[] for account in selected}
            if selected:
                if self.redis:
                    rows=self.query_graph(self.graph,impact_explanations_cypher(target,selected,path_limit))[0][0]
                    for account,paths in rows: explanations[account]=paths
                else:
                    rows=self.sql.execute(IMPACT_EXPLANATIONS_SQL,
                        (selected,MAX_DEPTH,target,path_limit)).fetchall()
                    for account,path,weight in rows: explanations[account].append((path,float(weight)))
            for account,fraction,direct,paths,value in ranked:
                if len(explanations[account])!=min(int(paths),path_limit):
                    self.revision=None;self.error='Projection changed between aggregation and explanations'
                    raise RuntimeError(self.error)
            portfolios=[]
            for account,fraction,direct,paths,value in ranked:
                portfolios.append({'accountId':int(account[1:]),'name':self.nodes[account]['name'],
                    'portfolioValue':value,'exposureValue':value*fraction,'totalFraction':fraction,
                    'directFraction':direct,'indirectFraction':fraction-direct,'pathCount':paths,
                    'pathsTruncated':paths>path_limit,
                    'paths':[{'nodes':[self.nodes[node] for node in path],
                              'fraction':float(weight),'exposureValue':value*float(weight)}
                             for path,weight in explanations[account]]})
            return {**self.status(),'target':target,'exposedPortfolioCount':int(count),
                    'totalExposureValue':float(total),'pathCount':int(path_count),
                    'portfoliosTruncated':count>limit,'portfolios':portfolios,
                    'elapsedMs':round((time.perf_counter()-start)*1000,3)}


IMPACT_SQL = """WITH RECURSIVE walk(node,path,weight,depth) AS (
    SELECT %s::text,ARRAY[%s::text],1.0::float8,0
    UNION ALL SELECT e.source,e.source||w.path,w.weight*e.weight,w.depth+1
    FROM walk w JOIN exposure.projected_edges e ON e.target=w.node
    WHERE w.depth<%s AND NOT e.source=ANY(w.path)
) SELECT w.path,w.weight FROM walk w
  JOIN exposure.projected_nodes n ON n.id=w.node
  WHERE n.kind='account' AND w.depth>0"""


def impact_cypher(target):
    # WITH anchors the indexed corporate target before reverse traversal.
    # Collect into one result row: FalkorDB's default RESULTSET_SIZE=10000
    # otherwise silently truncates the economic paths and undercounts exposure.
    return (f'MATCH (t:Entity {{id:{json.dumps(target)}}}) WITH t '
            f'MATCH p=(t)<-[:EXPOSURE*1..{MAX_DEPTH}]-(a:Entity) '
            "WHERE a.kind='account' "
            'RETURN collect([[n IN nodes(p) | n.id], '
            'reduce(w=1.0, r IN relationships(p) | w*r.weight)])')


IMPACT_AGGREGATE_SQL = """WITH RECURSIVE walk(node,weight,depth,through_fund) AS (
    SELECT %s::text,1.0::float8,0,false
    UNION ALL SELECT e.source,w.weight*e.weight,w.depth+1,w.through_fund OR n.kind='fund'
    FROM walk w JOIN exposure.projected_edges e ON e.target=w.node
    JOIN exposure.projected_nodes n ON n.id=e.source WHERE w.depth<%s
), totals AS (
    SELECT w.node,n.portfolio_value,sum(w.weight) AS fraction,
           sum(CASE WHEN NOT through_fund THEN w.weight ELSE 0 END) AS direct,count(*) AS paths
    FROM walk w JOIN exposure.projected_nodes n ON n.id=w.node
    WHERE n.kind='account' AND w.depth>0 GROUP BY w.node,n.portfolio_value
), ranked AS (
    SELECT *,row_number() OVER (ORDER BY floor(fraction*portfolio_value*100+0.5) DESC,
                                           substring(node from 2)::int) AS rank FROM totals
) SELECT count(*),coalesce(sum(fraction*portfolio_value),0),coalesce(sum(paths),0),
    coalesce(jsonb_agg(jsonb_build_array(node,fraction,direct,paths,portfolio_value) ORDER BY rank)
             FILTER (WHERE rank<=%s),'[]'::jsonb) FROM ranked"""

IMPACT_EXPLANATIONS_SQL = """WITH RECURSIVE walk(account,node,path,weight,depth) AS (
    SELECT id,id,ARRAY[id],1.0::float8,0 FROM unnest(%s::text[]) id
    UNION ALL SELECT w.account,e.target,w.path||e.target,w.weight*e.weight,w.depth+1
    FROM walk w JOIN exposure.projected_edges e ON e.source=w.node WHERE w.depth<%s
), ranked AS (
    SELECT account,path,weight,row_number() OVER (PARTITION BY account ORDER BY weight DESC,path COLLATE "C") AS rank
    FROM walk WHERE node=%s AND depth>0
) SELECT account,path,weight FROM ranked WHERE rank<=%s ORDER BY account,rank"""


def aggregate_impact_cypher(target,limit):
    return (f'MATCH (t:Entity {{id:{json.dumps(target)}}}) WITH t '
            f'OPTIONAL MATCH p=(t)<-[:EXPOSURE*1..{MAX_DEPTH}]-(a:Entity) WHERE a.kind="account" '
            'WITH t,a,reduce(w=1.0,r IN relationships(p)|w*r.weight) AS weight, '
            'any(n IN nodes(p) WHERE n.kind="fund") AS indirect '
            'WITH t,a,sum(weight) AS fraction,sum(CASE WHEN indirect THEN 0.0 ELSE weight END) AS direct,count(*) AS paths '
            'ORDER BY floor(fraction*a.value*100+0.5) DESC,toInteger(substring(a.id,1)) '
            'WITH t,collect(CASE WHEN a IS NULL THEN null ELSE [a.id,fraction,direct,paths,a.value] END) AS rows '
            'RETURN size(rows),reduce(total=0.0,r IN rows|total+r[1]*r[4]), '
            f'reduce(total=0,r IN rows|total+r[3]),rows[0..{limit}]')


def impact_explanations_cypher(target,accounts,path_limit):
    return (f'UNWIND {json.dumps(accounts)} AS account MATCH (a:Entity {{id:account}}) WITH a '
            f'MATCH p=(a)-[:EXPOSURE*1..{MAX_DEPTH}]->(t:Entity {{id:{json.dumps(target)}}}) '
            'WITH a,[n IN nodes(p)|n.id] AS path,reduce(w=1.0,r IN relationships(p)|w*r.weight) AS weight '
            'ORDER BY a.id,weight DESC,path '
            f'WITH a,collect([path,weight])[0..{path_limit}] AS paths RETURN collect([a.id,paths])')
