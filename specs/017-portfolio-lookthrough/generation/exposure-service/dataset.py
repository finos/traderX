"""Deterministic, synthetic long-only universe; no downloaded/customer data."""
import argparse
import json
import random
from pathlib import Path

PROFILES = {'small': (30, 200, 80, 20), 'demo': (1000, 5000, 2000, 500),
            'benchmark': (100000, 10000, 4000, 1000)}


def generate(profile='demo', seed=42):
    if profile == 'impact':
        from impact_dataset import generate_impact
        return generate_impact()
    accounts, securities, entities, funds = PROFILES[profile]
    rng = random.Random(seed)
    nodes, links, positions = [], [], []
    def node(i, name, kind):
        nodes.append((i, name, kind, 100))
    def link(s, t, w=1):
        links.append((s, t, w))
    # Corporate chains with shared ultimate parents, up to four entity levels.
    for i in range(entities):
        node(f'E{i}', f'Synthetic corporate entity {i}', 'company')
        if i % 4:
            link(f'E{i}', f'E{i-1}')
    for i in range(securities):
        node(f'TX{i}', f'Synthetic {"fund" if i < funds else "security"} {i}',
             'fund' if i < funds else 'security')
        if i >= funds:
            link(f'TX{i}', f'E{(i-funds) % entities}')
    # Forward-only nesting prevents cycles. Every fund has 100 holdings at demo scale.
    count = min(100, securities-funds)
    for i in range(funds):
        nested = i+1 < funds and i % 3 != 2
        # Shared popular holdings plus deliberately nested funds create overlapping
        # paths; random rows alone rarely produce an interesting graph workload.
        common=list(range(funds,funds+min(5,count)))
        selected=common+rng.sample(list(range(funds+len(common),securities)),count-len(common)-int(nested))
        if nested: selected.append(i+1)
        for target in selected:
            weight=(.2 if target==i+1 else .8/(count-1)) if nested else 1/count
            link(f'TX{i}', f'TX{target}', weight)
    for i in range(accounts):
        account = 70000+i
        node(f'A{account}', f'Synthetic portfolio {i}', 'account')
        for security in rng.sample(range(securities), min(30, securities)):
            positions.append((account, f'TX{security}', rng.randint(1, 100)))
    # Twenty independently specified 2% direct + 12% indirect scenarios.
    # Isolated groups, two fund levels, fixed marks, denominator exactly $100,000.
    for i in range(20):
        a = 70000+i
        for suffix, kind in [('G','company'),('S','security'),('F','fund'),('N','fund'),('C','security')]:
            node(f'Z{i}{suffix}', f'Scenario {i} {suffix}', kind)
        link(f'Z{i}S', f'Z{i}G')
        link(f'Z{i}F', f'Z{i}N', .6)
        link(f'Z{i}F', f'Z{i}C', .4)
        link(f'Z{i}N', f'Z{i}S', .5)
        link(f'Z{i}N', f'Z{i}C', .5)
        positions = [p for p in positions if p[0] != a]
        positions.extend([(a,f'Z{i}S',20),(a,f'Z{i}F',400),(a,f'Z{i}C',580)])
    return {'profile': profile, 'seed': seed, 'asOf': '2026-11-12T00:00:00Z',
            'nodes': nodes, 'links': links, 'positions': positions,
            'scenarios': [{'accountId':70000+i,'target':f'Z{i}G','expectedFraction':.14,
                           'expectedDirect':.02,'expectedIndirect':.12} for i in range(20)]}


def seed_database(dsn, data):
    import psycopg
    with psycopg.connect(dsn) as db:
        db.execute(Path(__file__).with_name('schema.sql').read_text())
        # Seeding is one-time, serialized and non-destructive on restart.
        db.execute('SELECT pg_advisory_xact_lock(17018)')
        current = db.execute('SELECT profile,seed FROM exposure.metadata').fetchone()
        if current:
            if current != (data['profile'],data['seed']):
                raise ValueError('Existing dataset profile/seed differs; use a separate database')
            return
        account_ids=[int(row[0][1:]) for row in data['nodes'] if row[2]=='account']
        if db.execute('SELECT 1 FROM Accounts WHERE id=ANY(%s) LIMIT 1',(account_ids,)).fetchone():
            raise ValueError('Synthetic account namespace overlaps existing accounts; use an isolated demo database')
        with db.cursor() as cur:
            with cur.copy('COPY exposure.nodes (id,name,kind,mark) FROM STDIN') as copy:
                for row in data['nodes']: copy.write_row(row)
            with cur.copy('COPY exposure.links (source,target,weight) FROM STDIN') as copy:
                for row in data['links']: copy.write_row(row)
        for account, name, kind, _ in data['nodes']:
            if kind == 'account':
                db.execute('INSERT INTO Accounts(id,displayname) VALUES(%s,%s) ON CONFLICT DO NOTHING',
                           (int(account[1:]),name))
                db.execute("INSERT INTO AccountUsers(accountid,username) VALUES(%s,'user01') ON CONFLICT DO NOTHING",
                           (int(account[1:]),))
        with db.cursor() as cur:
            with cur.copy('COPY Positions (accountid,security,quantity,updated,averagecostbasis) FROM STDIN') as copy:
                for account, security, quantity in data['positions']:
                    copy.write_row((account,security,quantity,data['asOf'],100))
        db.execute('INSERT INTO exposure.metadata(profile,seed,as_of) VALUES(%s,%s,%s)',
                   (data['profile'],data['seed'],data['asOf']))
        db.execute("SELECT setval('accounts_seq', GREATEST((SELECT last_value FROM accounts_seq), (SELECT MAX(id) FROM Accounts)+1), false)")


if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--profile',choices=[*PROFILES,'impact'],default='demo')
    parser.add_argument('--seed',type=int,default=42)
    parser.add_argument('--output',required=True)
    args=parser.parse_args()
    Path(args.output).write_text(json.dumps(generate(args.profile,args.seed),separators=(',',':'))+'\n')
