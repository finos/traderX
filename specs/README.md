# Spec Kit Feature Catalog

This repository now uses the GitHub Spec Kit canonical structure at repo root:

- `.specify/` for templates, scripts, and constitution
- `specs/NNN-feature-name/` for feature-scoped spec artifacts

## Active Feature Packs

- `001-baseline-uncontainerized-parity`
- `002-edge-proxy-uncontainerized`
- `003-containerized-compose-runtime`
- `004-postgres-database-replacement`
- `005-messaging-nats-replacement`
- `006-observability-lgtm-compose`
- `007-pricing-awareness-market-data`
- `008-order-management-matcher`
- `009-kubernetes-runtime`
- `010-tilt-kubernetes-dev-loop`
- `011-platform-convergence-c3`
- `012-radius-kubernetes-platform`

## Transitional Note

Legacy `TraderSpec/` migration artifacts have been removed after Phase C cleanup. New requirements work is authored in numbered root `specs/` feature directories.

State lineage and generated-branch publish conventions are tracked in:

- `catalog/state-catalog.json`
