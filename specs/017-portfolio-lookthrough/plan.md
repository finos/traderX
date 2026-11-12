# Plan: Portfolio Look-Through

Inherit `009-order-management-matcher` through the canonical sequential generator. Install the shared Python exposure service from state 017 into the C2 Compose runtime; select the backend through configuration. Keep PostgreSQL as system of record.

A repeatable-read snapshot combines reference links and current TraderX Positions at fixed valuation marks. SQL projection replacement is transactional; FalkorDB builds an immutable graph before pointer swap. Full snapshot reconciliation recovers missed source changes without a broker dependency. This intentionally simple strategy is measurable and replaceable with CDC later.

Validate generated Compose, functional SQL/Cypher parity, source mutations, projection failure/recovery, HTTP contracts, browser behavior and repository gates. Benchmark results record dataset, latency, source revision and backend without asserting a speedup.
