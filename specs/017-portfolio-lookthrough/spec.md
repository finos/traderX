# Feature Specification: Portfolio Look-Through

Status: Implemented. Parent: `009-order-management-matcher`.

## User stories
A portfolio manager discovers shared corporate exposure across direct securities, nested funds and corporate parents, then follows the contributing paths.
A presenter compares PostgreSQL and FalkorDB using identical data, APIs, and independently specified outcomes.

## Functional requirements
- FR-01701: Generate small, demo, and benchmark synthetic datasets with stable seed and identifiers, 20 independently specified 14% exposure scenarios, and no customer data.
- FR-01702: Read synthetic account positions from TraderX PostgreSQL Positions; preserve inherited trading services and data. Seed once transactionally; never reset a changed portfolio on restart.
- FR-01703: Traverse weighted paths to corporate targets, summing separate economic contributions; expose direct, indirect and total fractions, monetary value, and bounded explanation paths.
- FR-01704: Serve the same exposure API and UI for both implementations, with revision, fixed valuation timestamp and source-check freshness.
- FR-01705: Poll a repeatable-read source snapshot every two seconds. Publish a replacement projection only after it is complete; reject reads when synchronization fails.
- FR-01706: Execute recursive SQL on indexed PostgreSQL projection edges.

## Nonfunctional requirements
- NFR-01701: Read-only HTTP endpoints; no public source mutation endpoint. Parameterize SQL and escape Cypher values. Limit path explanation responses to 1,000 and database queries to ten seconds.
- NFR-01702: Support current-snapshot, single-currency long-only portfolios with fixed $100 synthetic marks. Fail closed on unknown marks, shorts, cycles, invalid fund weights or depth exceeding 12. Historical as-of queries and market-risk loss estimates are outside scope.
- NFR-01703: Preserve older states; keep durable sources in this feature pack and generate runtime artifacts. Observe projection health and source-check age via Prometheus.

## Acceptance scenarios
1. Given account 70000 and target Z0G, show 2% direct + 12% indirect = 14% total and two contributing paths.
2. Change its direct security quantity in Positions; observe a new revision and correctly changed denominator and exposure in both backends.
3. Change a nested-fund allocation while preserving total weights; observe agreement in both engines.
4. Stop FalkorDB or introduce invalid source data; return 503 instead of a misleading successful result. Restart and rebuild to recover.
5. Request a target containing quote/injection syntax; return 404 without mutating the graph.
6. Restart seeding with the same profile; retain changed positions. Reject a conflicting profile.
