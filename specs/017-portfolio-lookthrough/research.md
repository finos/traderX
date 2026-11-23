# Design decisions

Use a graph read model beside PostgreSQL, keeping transactional trade ownership intact. Compare actual recursive SQL and Cypher traversal, not an in-memory graph impersonating either database. Current snapshot marks separate graph correctness from market-data race conditions. Polling is a deliberate initial implementation with visible freshness; full rebuild cost must be measured before claiming suitability at benchmark scale.

Use versioned graphs and a process lock for query/swap safety. One service instance per database is supported in this demo; multi-replica coordination is a future extension.
