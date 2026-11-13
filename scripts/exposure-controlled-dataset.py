#!/usr/bin/env python3
"""Seed a size-control fixture without changing either baseline query subgraph.

Requires an isolated database already initialized with the TraderX schema.
Existing data is never reset. Use a fresh database for each account count.
"""
import argparse
import json
import os
from pathlib import Path
import random
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'specs/017-portfolio-lookthrough/generation/exposure-service'))
from dataset import generate, seed_database


def generate_controlled(accounts):
    if accounts < 1000:
        raise ValueError('The fixed demo control contains 1000 accounts')
    data = generate('demo')
    data['profile'] = f'controlled-{accounts}'
    # These entities are disconnected from both baseline query targets.
    # Include them at every size, even when there are no additional accounts.
    data['nodes'].append(('CONTROL_COMPANY', 'Unrelated corporate entity', 'company', 100))
    for index in range(100):
        ticker = f'CTRL_S{index}'
        data['nodes'].append((ticker, f'Unrelated security {index}', 'security', 100))
        data['links'].append((ticker, 'CONTROL_COMPANY', 1))
    rng = random.Random(17018)
    for index in range(accounts - 1000):
        account = 80000 + index
        data['nodes'].append((f'A{account}', f'Unrelated portfolio {index}', 'account', 100))
        for security in rng.sample(range(100), 30):
            data['positions'].append((account, f'CTRL_S{security}', rng.randint(1, 100)))
    return data


def query_fixture(data, account):
    """Reachable reference graph plus source holdings; independent of Engine."""
    holdings = sorted(row for row in data['positions'] if row[0] == account)
    adjacent = {}
    for source, target, weight in data['links']:
        adjacent.setdefault(source, []).append((target, weight))
    reachable = {row[1] for row in holdings}
    pending = list(reachable)
    while pending:
        for target, _ in adjacent.get(pending.pop(), []):
            if target not in reachable:
                reachable.add(target)
                pending.append(target)
    return {
        'holdings': holdings,
        'nodes': sorted(row for row in data['nodes'] if row[0] in reachable),
        'links': sorted(row for row in data['links'] if row[0] in reachable),
        'asOf': data['asOf'],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--accounts', type=int, choices=(1000, 10000, 100000), required=True)
    args = parser.parse_args()
    started = time.perf_counter()
    data = generate_controlled(args.accounts)
    baseline = generate('demo')
    for account in (70000, 70020):
        if query_fixture(data, account) != query_fixture(baseline, account):
            raise RuntimeError('Control changed the queried portfolio subgraph')
    seed_database(os.environ['EXPOSURE_TEST_DSN'], data)
    print(json.dumps({'profile': data['profile'], 'accounts': args.accounts,
                      'nodes': len(data['nodes']), 'referenceLinks': len(data['links']),
                      'positions': len(data['positions']),
                      'generateAndSeedSeconds': round(time.perf_counter() - started, 3),
                      'fixedQueries': [{'account': 70000, 'target': 'Z0G'},
                                       {'account': 70020, 'target': 'E0'}]}, indent=2))


if __name__ == '__main__':
    main()
