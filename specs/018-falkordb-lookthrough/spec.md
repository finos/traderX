# Feature Specification: FalkorDB Portfolio Look-Through

Status: Implemented. Parent: `017-portfolio-lookthrough`.

Experiment evaluation: **Draft**. The baseline implementation is validated locally, but a product-level database advantage has not been established. See [revised hypothesis and test design](../../docs/benchmarks/portfolio-lookthrough-experiment-design.md).

## User stories
A portfolio manager discovers shared corporate exposure across direct securities, nested funds and corporate parents, then follows the contributing paths.
A presenter compares PostgreSQL and FalkorDB using identical data, APIs, and independently specified outcomes.

## Functional requirements
- FR-01801: Generate small, demo, and benchmark synthetic datasets with stable seed and identifiers, 20 independently specified 14% exposure scenarios, and no customer data.
- FR-01802: Read synthetic account positions from TraderX PostgreSQL Positions; preserve inherited trading services and data. Seed once transactionally; never reset a changed portfolio on restart.
- FR-01803: Traverse weighted paths to corporate targets, summing separate economic contributions; expose direct, indirect and total fractions, monetary value, and bounded explanation paths.
- FR-01804: Serve the same exposure API and UI for both implementations, with revision, fixed valuation timestamp and source-check freshness.
- FR-01805: Poll a repeatable-read source snapshot every two seconds. Publish a replacement projection only after it is complete; reject reads when synchronization fails.
- FR-01806: Execute variable-depth Cypher in a real FalkorDB graph. Rebuild after graph loss or service restart, and atomically switch completed graph versions.

- FR-01807: Assess firm-wide corporate-group impact with one reverse traversal; rank exposed portfolios by monetary exposure and explain direct and shared-fund routes. Compute complete totals before limiting returned portfolios/paths.
- FR-01808: Provide an analytical firm-wide fixture with direct, shared-fund, mixed and unexposed portfolios; vary account count and fund depth independently while preserving the expected economic fractions.

## Nonfunctional requirements
- NFR-01801: Read-only HTTP endpoints; no public source mutation endpoint. Parameterize SQL and escape Cypher values. Limit path explanation responses to 1,000 and database queries to ten seconds.
- NFR-01802: Support current-snapshot, single-currency long-only portfolios with fixed $100 synthetic marks. Fail closed on unknown marks, shorts, cycles, invalid fund weights or depth exceeding 12. Historical as-of queries and market-risk loss estimates are outside scope.
- NFR-01803: Preserve older states; keep durable sources in this feature pack and generate runtime artifacts. Observe projection health and source-check age via Prometheus.

The exposure view is an independent addition with TraderX branding, a link from the trading header, and a return-to-trading link. It displays monetary exposure alongside fractions; errors clear previous results and valuation metadata.

## Acceptance scenarios
1. Given account 70000 and target Z0G, show 2% direct + 12% indirect = 14% total and two contributing paths.
2. Change its direct security quantity in Positions; observe a new revision and correctly changed denominator and exposure in both backends.
3. Change a nested-fund allocation while preserving total weights; observe agreement in both engines.
4. Stop FalkorDB or introduce invalid source data; return 503 instead of a misleading successful result. Restart and rebuild to recover.
5. Request a target containing quote/injection syntax; return 404 without mutating the graph.
6. Restart seeding with the same profile; retain changed positions. Reject a conflicting profile.

## Firm-wide impact acceptance

The primary experiment is now corporate-group impact: which portfolios are exposed, and through which funds? The independent `/exposure/impact` view is linked from TraderX. `EXPOSURE_PROFILE=impact` seeds 1,000 portfolios with two shared fund layers in a fresh database; benchmark fixtures vary depth separately.

7. Return correct monetary rankings and all-book totals with `limit=1` and `pathLimit=1`; limits must not change aggregates.
8. Match analytical answers and SQL/Cypher paths for more than 10,000 economic paths, exceeding FalkorDB's default row cap without silently losing results.
9. A shared-fund allocation change affects every dependent portfolio; a direct position change updates monetary ranking.
10. Show no exposed portfolios for an unheld group; clear old rankings on errors. Exposure is not an event-loss prediction.

The retained full-path baseline enumerates paths and uses shared application aggregation; the public endpoint now uses the database-side strategy described below. Response bounds do not bound traversal memory; measure complexity, update cost and concurrency before making capacity claims.

## Database-side aggregation experiment

- FR-01809: Compute complete portfolio totals and monetary ranking inside the selected database, then retrieve bounded explanation paths for only the selected portfolios in one additional batch query. Hold one projection revision across both phases.
- Keep the full-path strategy as `impact_paths` for paired benchmarks; the public impact endpoint uses the aggregate strategy with the same response contract.
- Project portfolio values atomically with edge weights/node kinds so both database phases use the same source valuation.
- Validate analytical answers and exact selected explanation paths against the full-path strategy, including shared-fund and position updates. Rank nonnegative monetary exposure to cents (half up), then numeric account ID.
- Measure database and strategy as separate factors with rotated condition order; do not attribute client-transfer savings solely to a database choice.
