# Spec: NF 04 Redis Caching

- `stepId`: `nf-04-redis-caching`
- `inheritsFrom`: `nf-03-observability`
- `requirementMode`: `nfr-overlay-only`

## NFR Additions

- Cache-aside strategy for high-read endpoints.
- Cache invalidation policy and TTL controls.
- Cache hit/miss telemetry.

## Acceptance

- Defined endpoints achieve target hit-rate thresholds.
- Cache coherence tests pass for update scenarios.
