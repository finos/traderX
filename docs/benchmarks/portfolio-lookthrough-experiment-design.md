# Portfolio exposure experiment: revised hypothesis and test design

Status: **draft**. Tracks issue #498 and draft PR #499. The initial implementation and measurements are a baseline, not evidence that adding a graph database is justified.

## Decision to make

Does a graph read model improve a representative portfolio-exposure task enough to justify its synchronization, operational and resource costs over indexed recursive PostgreSQL?

The current evidence establishes a traversal advantage on some small overlapping queries. It does not establish a compelling product advantage: absolute savings are small, the larger profile changes query shape, and graph projection construction is substantially slower in this implementation.

## Candidate business tasks

1. **Firm-wide impact analysis:** a corporate-group event occurs; identify exposed portfolios, rank their monetary exposure, and explain the leading contributing paths. This is the confirmed primary task. It should use one aggregate query per backend, not handicap SQL with a loop of portfolio requests.
2. **Complex portfolio explanation:** explain one portfolio's exposure through shared underlying holdings and nested funds. Keep the existing API as the baseline task, with realistic bounded nesting and a separate stress case.

Do not select only examples where FalkorDB wins. Keep direct/simple portfolios and PostgreSQL-friendly cases in the report.

## Falsifiable hypotheses

- **H1, unrelated growth:** with the queried portfolio subgraph held identical, adding unrelated portfolios should not materially change indexed-query latency. This is a control, not an expectation that FalkorDB must win.
- **H2, path overlap:** as economically distinct contributing paths increase, FalkorDB may reduce traversal latency while producing the same aggregate and explanation paths. A relative speedup is useful only if the absolute improvement addresses an agreed response-time or throughput requirement.
- **H3, firm-wide impact:** reverse traversal through shared funds may improve the time to identify and rank all exposed portfolios. Compare equivalent set-based queries and identical output; do not confuse a different API strategy with a database advantage.
- **H4, freshness/cost:** any query advantage must remain useful after accounting for initial load, changed-source reconciliation, unavailability under the 15-second freshness rule, memory, and update frequency. The current full-snapshot design may fail this hypothesis even if H2 or H3 succeeds.

## Controlled matrix

Vary one axis at a time, then test selected combined cases:

| Axis | Proposed values | Keep fixed |
| --- | --- | --- |
| Unrelated portfolios | 1k, 10k, 100k | Exact queried nodes, edges, positions, marks and result paths |
| Fund layers | 0, 1, 2, 3; deeper only as labeled stress | Portfolio value, target exposure, global account count |
| Shared holdings/path count | Low, medium, high; record actual paths | Layer count and valuation |
| Impact fan-out | Few vs many exposed portfolios | Corporate event/target and query semantics |
| Concurrent requests | 1, 4, 16 | Data revision, query mix and hardware |
| Source updates | None, one position, one shared fund allocation | Query workload and correctness oracle |

Report both full result computation and bounded explanations. A response limit must not silently truncate aggregate exposure. Use analytical known answers and cross-backend path agreement before timing. Query timeouts and failed requests count as results, not discarded samples.

## Measurement and interpretation

- Record versions, host/container limits, dataset hashes, actual path counts and exposed-account counts.
- Use identical source snapshots, query intent and output shape. Inspect SQL plans and graph indexes before interpreting differences.
- Warm both backends; report median, p95, p99, throughput and failures. Repeat runs and alternate backend order. Keep projection work outside warm query timing, but report it separately and measure mixed reads/updates as another scenario.
- Retain raw observations and reproduction commands. Label shared-host measurements and synthetic topology; do not imply they represent a customer book.
- Agree on a business response-time/freshness target before calling a result a product improvement. Do not invent a threshold after seeing which backend wins.
- Publish neutral and negative results. If both systems meet the requirement and PostgreSQL is operationally simpler, that is a valid outcome.

## Exit criteria for the draft

- Primary business task confirmed: firm-wide corporate-group impact. Validate the synthetic topology with domain reviewers.
- Implement equivalent queries and independent correctness fixtures.
- Run the controlled matrix, including simple controls and update/freshness costs.
- Explain which hypothesis is supported, weakened or still unresolved; distinguish a query optimization from a product advantage.
- Keep PR #499 in draft until the example and evidence are reviewed. Full C2 trading end-to-end regression remains a separate unrun validation item.

## Implemented size control

`scripts/exposure-controlled-dataset.py --accounts 1000|10000|100000` seeds a fresh database already initialized with the inherited TraderX schema. It preserves the demo data and adds only disconnected portfolios/securities. Before seeding, it compares the complete reachable reference graph, positions and marks for accounts 70000 and 70020 with the original demo fixture. `scripts/test-exposure-controlled-dataset.py` verifies this invariant, deterministic data, account uniqueness and growth counts; CI runs these checks.

For each size, use a separate initialized database and run:

```bash
export EXPOSURE_TEST_DSN=postgresql://traderx:traderx@localhost:5432/isolated_control_db
export EXPOSURE_TEST_REDIS_URL=redis://localhost:6379
python scripts/exposure-controlled-dataset.py --accounts 10000 > control-setup.json
python scripts/benchmark-exposure.py > control-results.json
```

This tests H1 only. It does not substitute for the pending business-task selection, complexity/concurrency matrix or incremental-update experiment.

## First size-control pilot — 13 November 2026

The first controlled run preserves 2 paths for the known scenario and **25 paths** for the overlapping query at both sizes. This removes the earlier 25-versus-8-path confound. Both backends agree on the results. Values below are median / p95 milliseconds.

| Accounts | Query | PostgreSQL | FalkorDB |
| ---: | --- | ---: | ---: |
| 1,000 | known-concentration | 0.275 / 1.281 | 0.591 / 0.984 |
| 1,000 | overlapping-funds | 4.609 / 6.676 | 1.276 / 1.740 |
| 10,000 | known-concentration | 0.523 / 1.486 | 1.031 / 1.889 |
| 10,000 | overlapping-funds | 5.021 / 10.538 | 2.720 / 4.610 |

This is a single shared-host pilot, with fixed PostgreSQL-then-FalkorDB ordering and no concurrency. It is not enough to infer a scaling curve or accept H1. The millisecond advantage still does not establish a product benefit. Repeat/alternate runs, plan inspection and the selected business workload remain pending. The controlled **100k** run has not been run; the earlier 100k profile results are a different fixture and must not be substituted.

Raw results: [1k control](portfolio-lookthrough-controlled-1000.json), [10k control](portfolio-lookthrough-controlled-10000.json). Setup counts/timings: [1k](portfolio-lookthrough-controlled-1000-setup.json), [10k](portfolio-lookthrough-controlled-10000-setup.json).

## Confirmed primary task: firm-wide corporate impact

The selected question is: **which portfolios are exposed to a corporate group, and through which funds?** The implementation now adds `/api/impact` and `/exposure/impact` while retaining single-portfolio look-through as a control.

Both backends perform one reverse traversal from the target company. PostgreSQL has an index on projected edge targets and uses recursive SQL; Cypher explicitly anchors the target index with `WITH` before traversal. Both return economic paths to identical application aggregation/ranking code. Limits apply only to returned portfolios/explanations, never totals. This is an enumerating implementation, not a comparison of the best possible aggregation strategy for each database.

The analytical fixture varies portfolio count and fund layers independently. One quarter of accounts hold direct exposure, one quarter hold two shared funds plus unrelated holdings, one quarter mix direct and fund exposure, and one quarter are unexposed. Fund-heavy portfolios have larger asset values, so rankings expose their shared routes. Every final fund is 50% exposed to the group through two subsidiaries. Expected fractions, monetary totals, rankings and path counts are derived from these allocations independently of either engine. This is a synthetic stress/control topology, not a claim about a typical customer book.

A first rejected run revealed FalkorDB's default `RESULTSET_SIZE=10000`: returning one row per path silently lost data at 14,000 paths. The analytical oracle caught it. Both path queries now return a collected result rather than allowing the row cap to truncate exposure. The regression fixture explicitly exceeds 10,000 paths. This retains correctness but still materializes all paths, so memory and transfer cost must be measured. The server limit itself was not changed.

See [firm-wide results and screenshots](portfolio-impact.md). The PR stays in draft: the next design comparison should aggregate inside each database and retrieve explanations only for the ranked portfolios, with equivalent semantics for SQL and Cypher. Concurrency and realistic update cadence remain open.
