# Spec: NF 04 Distributed Caching

- `stepId`: `nf-04-distributed-caching`
- `inheritsFrom`: `nf-03-observability`
- `requirementMode`: `nfr-overlay-only`

## NFR Additions

- Multi-node/distributed caching strategy.
- Consistency and invalidation guarantees across nodes.
- Failure handling for cache cluster partitions.

## Acceptance

- Cache cluster operations meet availability targets.
- Consistency model is documented and tested.
