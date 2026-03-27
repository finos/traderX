# Spec: NF 05 Circuit Breakers

- `stepId`: `nf-05-circuit-breakers`
- `inheritsFrom`: `nf-04-redis-caching|nf-04-distributed-caching`
- `requirementMode`: `nfr-overlay-only`

## NFR Additions

- Circuit breaker and retry policy strategy.
- Bulkhead isolation for critical service boundaries.
- Failure-mode simulation and recovery checks.

## Acceptance

- Downstream failures trigger controlled degradation.
- Recovery behavior is observable and deterministic.
