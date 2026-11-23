# Exposure contract

GET /api/exposure?account=70000&target=Z0G&limit=100 returns totalFraction, directFraction, indirectFraction, portfolioValue, exposureValue, pathCount, pathsTruncated, paths (nodes and fraction), backend, revision, valuationAsOf, projectedAt, sourceCheckedAt and elapsedMs. Fractions use 0–1 units. Explain-path limit does not change aggregate totals.

GET /api/catalog returns accounts, corporate targets and status. GET /health returns 200 for a current healthy projection, otherwise 503. GET /metrics exposes Prometheus health and source-check-age gauges. Invalid input returns 400, unknown entities 404, unavailable projection 503. All routes are read-only. Ingress prefixes these paths with /exposure.
