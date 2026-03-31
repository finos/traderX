# Spec Kit Feature Catalog

This repository now uses the GitHub Spec Kit canonical structure at repo root:

- `.specify/` for templates, scripts, and constitution
- `specs/NNN-feature-name/` for feature-scoped spec artifacts

## Active Feature Packs

- `001-baseline-uncontainerized-parity`
- `002-edge-proxy-uncontainerized`
- `003-containerized-compose-runtime`
- `004-kubernetes-runtime`
- `005-radius-kubernetes-platform`
- `006-tilt-kubernetes-dev-loop`
- `007-messaging-nats-replacement`
- `009-postgres-database-replacement`
- `010-pricing-awareness-market-data`

## Transitional Note

Legacy `TraderSpec/` migration artifacts have been removed after Phase C cleanup. New requirements work is authored in numbered root `specs/` feature directories.

State lineage and generated-branch publish conventions are tracked in:

- `catalog/state-catalog.json`
