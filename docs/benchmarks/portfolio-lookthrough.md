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

## Review rerun — 13 November 2026

The continuation on macOS ARM64 (10 logical CPUs, Python 3.14.3, Docker Desktop, PostgreSQL 16.4 and FalkorDB 4.16.0) independently reran the demo comparison after fixing revisions for proportional position changes and rejecting missing graph reads. Both databases use normal local Docker storage. These runs share a development host with other workloads and are not isolated capacity measurements.

| Demo query | Paths | PostgreSQL median / p95 | FalkorDB median / p95 |
| --- | ---: | ---: | ---: |
| Known concentration | 2 | 0.306 / 1.279 ms | 0.730 / 1.444 ms |
| Overlapping funds | 25 | 7.286 / 14.001 ms | 1.365 / 1.933 ms |

Initial projection: PostgreSQL 0.683 s; FalkorDB 2.105 s. See [review JSON](portfolio-lookthrough-local-review.json). Do not compare these absolute times directly with the earlier Linux host.

**Current conclusion:** FalkorDB shows a traversal advantage on the overlapping examples, but this experiment has not established a compelling product advantage or a general major-improvement claim.

For an occasional interactive lookup, both query latencies are already small. A roughly six-millisecond median saving on the overlapping query alone does not justify adding a graph database. The useful follow-up questions are how latency changes with overlapping paths and concurrency, how often source updates occur, and whether projection/reconciliation cost and freshness meet the product's needs. Dataset size alone does not establish those answers.

## 100,000-account profile — 13 November 2026

The opt-in profile was run on the same ARM64 host: 100,000 accounts, 10,000 core securities (1,000 funds), 4,000 corporate entities and 100 scenario entities. Total: 114,100 nodes, 112,100 reference links and 2,999,460 positions, producing 3,111,560 relationships. Generation plus one-time seeding took 54.83 seconds. Both databases used normal Docker storage; an earlier temporary-memory-storage attempt ran out of its allocation and is excluded. Reclaiming unused Docker build cache resolved the original disk-space blocker.

| Query | Paths | PostgreSQL median / p95 | FalkorDB median / p95 |
| --- | ---: | ---: | ---: |
| Known concentration | 2 | 0.641 / 1.364 ms | 1.060 / 2.934 ms |
| Overlapping funds | 8 | 2.315 / 6.905 ms | 0.994 / 3.515 ms |

Initial projection creation took **11.010 s for PostgreSQL** and **89.101 s for FalkorDB**. An unchanged-source full refresh took **5.058 s** and **4.916 s**, respectively (one measured refresh per backend). Both backends agreed on fractions and path counts. See [full benchmark JSON](portfolio-lookthrough-100k.json) and [dataset setup timing](portfolio-lookthrough-100k-setup.json).

The overlapping query has **8 paths in this profile, versus 25 in the demo**: changing the generator profile changes the securities and holdings. These measurements compare backends on identical data within each profile, but do **not** isolate the effect of database size across profiles. Larger global data did not automatically make these bounded portfolio queries slower. A controlled next experiment should keep the queried subgraph constant while scaling unrelated portfolios, then separately increase path overlap/depth and concurrent users.

Full-snapshot reconciliation is the clear limitation at this scale. The service sleeps two seconds *after* each refresh, so a five-second unchanged refresh gives roughly a seven-second polling cycle, not two-second freshness. A changed-source graph rebuild comparable to the measured 89-second initialization can exceed the 15-second freshness limit and cause temporary HTTP 503 responses. This prototype is suitable for an experiment, not evidence of production readiness for rapidly changing 100,000-account books. Incremental updates/CDC and measured concurrent load remain follow-up work. The 100k run checks the two benchmark queries; the complete nine-test regression suite was run on demo and small profiles, not the 100k profile.

To reproduce on isolated databases initialized with the inherited TraderX schema, install the exposure-service requirements and seed the desired profile once:

```bash
export EXPOSURE_TEST_DSN=postgresql://traderx:traderx@localhost:5432/traderx
export EXPOSURE_TEST_REDIS_URL=redis://localhost:6379
PYTHONPATH=specs/017-portfolio-lookthrough/generation/exposure-service python - <<'PYCODE'
import os
from dataset import generate, seed_database
seed_database(os.environ['EXPOSURE_TEST_DSN'], generate('benchmark'))
PYCODE
python scripts/benchmark-exposure.py > benchmark-100k.json
```

Use a fresh isolated database when changing profile. The benchmark includes source snapshot, validation and projection loading in initial projection time, but excludes refresh from query latency. Do not interpret these sequential local timings as concurrent throughput or end-user HTTP latency.

## Validation evidence

The database integration suite covers 20 independently specified 14% exposure scenarios, SQL/Cypher parity, position mutations and denominator changes, allocation changes, graph loss/rebuild, graph endpoint failure/recovery, invalid-source rejection, non-destructive reseeding, HTTP errors and injection-shaped target input. Browser checks exercise totals, monetary values, explanation paths, zero exposure, failure display and mobile rendering. The review rerun passed nine integration tests on each of the small and demo profiles, including proportional position scaling and missing-graph rejection. A real FalkorDB container restart also recovered successfully. Both states regenerated sequentially; Compose configuration, lifecycle dry-runs, lineage/lifecycle policies and all four repository quality gates passed. The exposure container image and inherited Angular production build passed (existing initial-bundle warning). The screenshots below show the independent TraderX-branded addition served by the built image against real databases on the small profile. Full C2 trading end-to-end regression remains unrun.

![State 017 PostgreSQL exposure](../img/portfolio-lookthrough/state017.png)

![State 018 FalkorDB exposure](../img/portfolio-lookthrough/state018.png)
