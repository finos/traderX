# Spec Kit Feature Catalog

This repository now uses the GitHub Spec Kit canonical structure at repo root:

- `.specify/` for templates, scripts, and constitution
- `specs/NNN-feature-name/` for feature-scoped spec artifacts

## Active Feature Packs

- `001-baseline-uncontainerized-parity` - Simple App - Base Uncontainerized App requirements for the current TraderX generated stack.
  - includes `fidelity-profile.md` for technical NFR/code-closeness targets.
  - includes `system/**`, `components/**`, and `conformance/**` artifacts used by generation/compliance scripts.

## Planned Next Feature Packs

- `002-edge-proxy-uncontainerized` (draft)
  - introduces an edge routing/proxy boundary for browser traffic.
  - expected to be primarily NFR/topology deltas.

- `003-containerized-compose-runtime` (draft)
  - introduces Docker/Docker Compose runtime packaging for the baseline stack.
  - expected to be primarily runtime/operations NFR deltas.

## Transitional Note

Legacy migration artifacts under `TraderSpec/` remain available during cutover, but new requirements work should be authored in numbered root `specs/` feature directories.

State lineage and generated-branch publish conventions are tracked in:

- `catalog/state-catalog.json`
