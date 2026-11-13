# Counterparty dependency investigation — experimental protocol

This is a standalone query prototype in draft PR #499 / issue #498. It does not
change the exposure API or claim production risk or sanctions functionality.

## Question and hypothesis

If Bank X becomes distressed, which portfolios depend on it through securities,
funds, issuer parents, guarantees, derivative counterparties or collateral issuers?
Return typed explanatory paths, not a sum of incomparable financial amounts.

Hypothesis: mixed-relationship, variable-depth investigation gives FalkorDB a
material latency or implementation advantage over indexed PostgreSQL. Before
measurement, the screening criterion is at least 2x lower p95 and 50 ms absolute
saving on a nonempty question. This is provisional, not an agreed business SLA.
A favorable result would justify further testing, not an adoption decision.

## Controlled comparison

- Same deterministic nodes and typed edges in both backends; isolated PostgreSQL
  database/schema and a unique disposable Falkor graph.
- Portfolio → shared funds → security → role-specific company → parent bank.
  Fund depths vary from one to three. Roles are ISSUED_BY, GUARANTEED_BY,
  COUNTERPARTY and COLLATERAL_ISSUER. These are synthetic dependency edges;
  security nodes abstract instruments, not production contractual models.
- All paths to a named bank, then each of four role filters, and an absent target.
  Complete sorted responses, maximum eight edges, no repeated node in a path.
  No top-k truncation or materialized answer on either side.
- PostgreSQL primary/source and covering target indexes; Falkor node ID index.
- Independent forward Python DFS from portfolios checks every timed answer;
  database queries traverse toward/from the bank. Handwritten cyclic fixture
  checks two known paths. Reparenting a guarantee provider checks changed answers.
- Four rounds with alternating backend order, two warmups and ten timed samples
  per condition per round. Timings include decoding and sorting, exclude oracle
  checking and loading. Raw values and source hashes retained.
- Sparse fixtures: 1,000 and 10,000 portfolios, 100 banks. A denser control uses
  10,000 portfolios and ten banks, changing the number of relevant paths.

## Limits and stopping rule

Shared-host, one client and synthetic topology. The fixture does not validate
business realism. Full reload verifies updated answers, not incremental freshness
or concurrent snapshot safety. Eight-edge bound must not be interpreted as
complete investigation of arbitrary real networks. No HTTP/UI latency measurement.
No full C2 trading regression. Engine-specific tuning and query plans need review
before concluding that either database cannot do better.

Do not add complexity merely to obtain a graph win. If both databases readily
meet an eventual business target and there is no credible maintainability benefit,
retain PostgreSQL and report the neutral finding. A UI or a graph-shaped data model
is not itself evidence for changing the database.

## Reproduction

Install the exposure service Python dependencies. Set EXPOSURE_TEST_DSN to a
**dedicated disposable database** and EXPOSURE_TEST_REDIS_URL to FalkorDB. The
probe replaces tables in the dependency_probe schema and cleans up its own graph.

```bash
python scripts/benchmark-counterparty-dependencies.py --accounts 10000 --banks 100 --output /tmp/dependencies.json
```

## Measured results (2026-11-13)

All 40 samples per backend/question matched the independent oracle. Relationship
replacement, absent-target and handwritten cyclic-path checks passed on both
backends for all three fixture runs. These are query prototype checks, not C2 tests.

| Portfolios / banks | Returned paths (all roles) | PostgreSQL median / p95 ms | Falkor median / p95 ms |
|---|---:|---:|---:|
| 1,000 / 100 | 80 | 0.82 / 1.04 | 4.03 / 5.21 |
| 10,000 / 100 | 800 | 3.47 / 5.57 | 20.92 / 22.83 |
| 10,000 / 10 | 8,000 | 23.90 / 32.70 | 200.95 / 207.64 |

### Individual questions at 10,000 portfolios / ten banks

| Question | Paths | PostgreSQL median / p95 ms | Falkor median / p95 ms |
|---|---:|---:|---:|
| issued_by | 2,000 | 14.82 / 19.60 | 77.31 / 81.38 |
| guaranteed_by | 2,000 | 14.78 / 16.79 | 77.63 / 80.79 |
| counterparty | 2,000 | 14.82 / 16.94 | 77.94 / 82.84 |
| collateral_issuer | 2,000 | 14.64 / 16.43 | 78.15 / 86.70 |
| absent | 0 | 0.29 / 0.63 | 0.31 / 0.64 |

### Interpretation

No tested question met the provisional graph-benefit criterion. PostgreSQL was
faster for the nonempty investigations. The richer relationship model therefore
did not by itself establish a reason to adopt FalkorDB. Both implementations are
compact; no measured development-effort advantage is claimed.

This remains a directed dependency-tracing workload, with bounded depth and
synthetic shared funds. It does not settle graph performance for temporal
transaction motifs, shortest-path searches or iterative contagion algorithms.
Further work should start from a verified user need rather than tuning the
fixture until a favorable graph result appears. Product UI integration is deferred.

During smoke testing, the initial Cypher plan scanned from portfolios. Explicitly
matching the bank and carrying it through WITH made the measured plan start at
its ID index. All published runs use that corrected plan. Both database plans
are embedded in the raw results. Query latency includes Python decoding and
sorting; redis-py has no hiredis installed. These results compare this client
stack and these queries, not isolated server execution speed.

Raw artifacts: [1k / 100 banks](dependencies-1000-100.json),
[10k / 100 banks](dependencies-10000-100.json),
[10k / ten banks](dependencies-10000-10.json). Each includes raw timings, plans,
client/server versions, correctness checks and source hashes.

