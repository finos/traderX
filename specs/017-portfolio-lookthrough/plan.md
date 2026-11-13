# Plan: Portfolio Look-Through

Inherit `009-order-management-matcher` through the canonical sequential generator. Install the shared Python exposure service from state 017 into the C2 Compose runtime; select the backend through configuration. Keep PostgreSQL as system of record.

A repeatable-read snapshot combines reference links and current TraderX Positions at fixed valuation marks. SQL projection replacement is transactional; FalkorDB builds an immutable graph before pointer swap. Full snapshot reconciliation recovers missed source changes without a broker dependency. This intentionally simple strategy is measurable and replaceable with CDC later.

Validate generated Compose, functional SQL/Cypher parity, source mutations, projection failure/recovery, HTTP contracts, browser behavior and repository gates. Benchmark results record dataset, latency, source revision and backend without asserting a speedup.

## Firm-wide impact experiment

The confirmed primary task is corporate-group impact across the book. Add a reverse-target index and atomic projected node kinds for SQL; anchor Cypher at the target index. Both backends enumerate complete economic paths and use shared aggregation/ranking. Preserve single-portfolio look-through as a control.

Use analytical direct/shared/mixed/unexposed portfolios, varying fund depth and account count separately. Test response-limit invariance, >10,000 paths, ranking updates and graph unavailability. Retain raw samples, alternating-order rounds, query plans and update cost. Publish negative findings. Keep PR #499 in draft; database-side aggregation with selective explanations and concurrency remain follow-up comparisons.
