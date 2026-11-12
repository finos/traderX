# Portfolio look-through: local validation and timings

Measured 12 November 2026 on the managed Linux x86_64 development host (5 visible CPUs), Python 3.12.14, PostgreSQL 16.4 and FalkorDB 4.16.0. This is a local demonstration microbenchmark, not a production capacity claim.

## Dataset and method

- 1,000 accounts, 5,000 core securities (including 500 funds), 2,000 corporate entities, plus 100 scenario entities: 8,100 entities total.
- 56,100 reference relationships and 29,460 current account positions: 85,560 projected relationships.
- Deliberately shared holdings and nested funds; maximum supported traversal depth 12.
- Same source revision, query contract, path formatting and results in both backends.
- Ten warmup requests then 100 sequential requests per query/backend. Both clients reuse database connections. Timings include client round trip and path formatting; reconciliation occurs outside the timed requests.
- No concurrent load, network-distance simulation, cache-flush experiment or million-edge capacity test. Container startup screenshots include an initial request and are not benchmark measurements.

## Results

| Query | Contributing paths | PostgreSQL median | FalkorDB median | PostgreSQL p95 | FalkorDB p95 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Known concentration: account 70000 → Z0G | 2 | 0.324 ms | 0.526 ms | 1.431 ms | 1.300 ms |
| Overlapping funds: account 70020 → E0 | 25 | 8.718 ms | 1.761 ms | 15.627 ms | 3.420 ms |

PostgreSQL is faster on the small known scenario. FalkorDB is approximately 5× faster at the median for this overlapping-fund query. Neither result establishes a universal database ranking. Initial projection creation took 0.781 seconds for PostgreSQL and 3.024 seconds for FalkorDB; the graph implementation trades additional projection work for traversal performance.

See [machine-readable results](portfolio-lookthrough-local.json) for source revision, p99 and individual query definitions. Reproduce with `scripts/benchmark-exposure.py`; use the disposable-database workflow in the state quickstarts. The opt-in benchmark profile with 100,000 accounts is available but was not used for these numbers.

## Validation evidence

The database integration suite covers 20 independently specified 14% exposure scenarios, SQL/Cypher parity, position mutations and denominator changes, allocation changes, graph loss/rebuild, graph endpoint failure/recovery, invalid-source rejection, non-destructive reseeding, HTTP errors and injection-shaped target input. Browser checks exercise totals, explanation paths, zero exposure, failure display and mobile rendering.

![State 017 PostgreSQL exposure](../img/portfolio-lookthrough/state017.png)

![State 018 FalkorDB exposure](../img/portfolio-lookthrough/state018.png)
