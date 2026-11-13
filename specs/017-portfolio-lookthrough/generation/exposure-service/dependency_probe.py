"""Standalone counterparty investigation probe; isolated from exposure projection.

Edges mean dependency, not additive financial exposure. Node-simple paths of at
most eight edges terminate at a named institution. No financial amounts implied.
"""
import json
import uuid
from collections import defaultdict

import psycopg
from redis import Redis

MAX_DEPTH = 8
ROLES = ('ISSUED_BY', 'GUARANTEED_BY', 'COUNTERPARTY', 'COLLATERAL_ISSUER')


def fixture(accounts, banks=100):
    if accounts < 1 or banks < 2:
        raise ValueError('Require positive accounts and at least two banks')
    nodes = {f'B{i:04}': 'bank' for i in range(banks)}
    edges = set()
    # Shared funds, varying depth; every leaf has four distinct dependencies.
    for i in range(banks * 2):
        security = f'S{i:05}'
        nodes[security] = 'security'
        for role_no, role in enumerate(ROLES):
            issuer = f'I{i:05}_{role_no}'
            nodes[issuer] = 'company'
            edges.add((security, issuer, role))
            edges.add((issuer, f'B{(i + role_no * 7) % banks:04}', 'PARENT'))
        previous = security
        for depth in range(1 + i % 3):
            fund = f'F{i:05}_{depth}'
            nodes[fund] = 'fund'
            edges.add((fund, previous, 'HOLDS'))
            previous = fund
        nodes[f'T{i:05}'] = 'fund'
        edges.add((f'T{i:05}', previous, 'HOLDS'))
    for account in range(accounts):
        node = f'A{account:07}'
        nodes[node] = 'portfolio'
        for offset in (0, 13):
            edges.add((node, f'T{(account + offset) % (banks * 2):05}', 'HOLDS'))
    return nodes, sorted(edges)


def oracle(nodes, edges, target, role=None):
    """Independent forward DFS from portfolios, never the DB reverse traversal."""
    adjacent = defaultdict(list)
    for source, dest, kind in edges:
        adjacent[source].append((dest, kind))
    result = []
    def visit(path, kinds):
        if path[-1] == target:
            if role is None or role in kinds:
                result.append((tuple(path), tuple(kinds)))
            return
        if len(kinds) == MAX_DEPTH:
            return
        for dest, kind in adjacent[path[-1]]:
            if dest not in path:
                visit(path + [dest], kinds + [kind])
    for node, kind in nodes.items():
        if kind == 'portfolio':
            visit([node], [])
    return sorted(result)


SQL = '''WITH RECURSIVE walk(node,path,kinds) AS (
 SELECT id,ARRAY[id]::text[],ARRAY[]::text[] FROM dependency_probe.nodes WHERE id=%s
 UNION ALL
 SELECT e.source,ARRAY[e.source]||w.path,ARRAY[e.kind]||w.kinds
 FROM walk w JOIN dependency_probe.edges e ON e.target=w.node
 WHERE cardinality(w.kinds)<8 AND NOT e.source=ANY(w.path)
) SELECT path,kinds FROM walk JOIN dependency_probe.nodes n ON n.id=walk.node
 WHERE n.kind='portfolio' AND (%s::text IS NULL OR %s=ANY(kinds))'''


class Probe:
    def __init__(self, dsn, redis_url):
        self.sql = psycopg.connect(dsn, autocommit=True)
        self.redis = Redis.from_url(redis_url, decode_responses=True, socket_timeout=60)
        self.graph = 'dependency_probe_' + uuid.uuid4().hex
        self.sql.execute('CREATE SCHEMA IF NOT EXISTS dependency_probe')
        self.sql.execute('CREATE TABLE IF NOT EXISTS dependency_probe.nodes(id text PRIMARY KEY,kind text NOT NULL)')
        self.sql.execute('CREATE TABLE IF NOT EXISTS dependency_probe.edges(source text NOT NULL,target text NOT NULL,kind text NOT NULL,PRIMARY KEY(source,target,kind))')
        self.sql.execute('CREATE INDEX IF NOT EXISTS dependency_probe_target ON dependency_probe.edges(target) INCLUDE(source,kind)')

    def graph_query(self, query):
        response = self.redis.execute_command('GRAPH.QUERY', self.graph, query, 'TIMEOUT', 30000, '--compact')
        def decode(value):
            kind, data = value
            return [decode(v) for v in data] if kind == 6 else data
        return [[decode(cell) for cell in row] for row in response[1]] if len(response) > 2 else []

    def load(self, nodes, edges):
        with self.sql.transaction():
            self.sql.execute('TRUNCATE dependency_probe.edges,dependency_probe.nodes')
            with self.sql.cursor() as cursor:
                with cursor.copy('COPY dependency_probe.nodes FROM STDIN') as copy:
                    for item in nodes.items(): copy.write_row(item)
                with cursor.copy('COPY dependency_probe.edges FROM STDIN') as copy:
                    for item in edges: copy.write_row(item)
        self.sql.execute('ANALYZE dependency_probe.nodes')
        self.sql.execute('ANALYZE dependency_probe.edges')
        if self.redis.exists(self.graph): self.redis.execute_command('GRAPH.DELETE', self.graph)
        self.graph_query('CREATE INDEX FOR (n:Dependency) ON (n.id)')
        values = list(nodes.items())
        for start in range(0, len(values), 500):
            literal = '[' + ','.join('{id:'+json.dumps(n)+',kind:'+json.dumps(k)+'}' for n,k in values[start:start+500]) + ']'
            self.graph_query('UNWIND '+literal+' AS row CREATE (:Dependency {id:row.id,kind:row.kind})')
        for kind in sorted({e[2] for e in edges}):
            selected = [e for e in edges if e[2] == kind]
            # Kinds originate exclusively in the controlled fixture.
            if not kind.replace('_','').isalpha(): raise ValueError('Invalid relationship')
            for start in range(0, len(selected), 500):
                literal = '[' + ','.join('{s:'+json.dumps(s)+',t:'+json.dumps(t)+'}' for s,t,_ in selected[start:start+500]) + ']'
                self.graph_query('UNWIND '+literal+' AS row MATCH (s:Dependency {id:row.s}),(t:Dependency {id:row.t}) CREATE (s)-[:'+kind+']->(t)')

    def cypher(self, target, role):
        if role is not None and role not in ROLES: raise ValueError('Invalid role')
        condition = '' if role is None else ' AND any(r IN relationships(p) WHERE type(r)='+json.dumps(role)+')'
        return ('MATCH (b:Dependency {id:'+json.dumps(target)+'}) WITH b MATCH p=(a:Dependency)-[*1..8]->(b) '
                "WHERE a.kind='portfolio' AND all(n IN nodes(p) WHERE single(m IN nodes(p) WHERE m.id=n.id))"+condition+
                ' RETURN [n IN nodes(p) | n.id], [r IN relationships(p) | type(r)]')

    def query(self, backend, target, role=None):
        if role is not None and role not in ROLES: raise ValueError('Invalid role')
        rows = (self.sql.execute(SQL, (target, role, role)).fetchall() if backend == 'postgres'
                else self.graph_query(self.cypher(target, role)))
        return sorted((tuple(path), tuple(kinds)) for path,kinds in rows)

    def close(self):
        if self.redis.exists(self.graph): self.redis.execute_command('GRAPH.DELETE', self.graph)
        self.redis.close()
        self.sql.close()
