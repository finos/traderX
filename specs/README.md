# Spec Kit Feature Catalog

This repository now uses the GitHub Spec Kit canonical structure at repo root:

- `.specify/` for templates, scripts, and constitution
- `specs/NNN-feature-name/` for feature-scoped spec artifacts

## Active Feature Packs

- `001-baseline-uncontainerized-parity` - baseline runtime and behavioral parity requirements for current TraderX generated stack.
  - includes `fidelity-profile.md` for technical NFR/code-closeness targets.
  - includes `system/**`, `components/**`, and `conformance/**` artifacts used by generation/compliance scripts.

## Transitional Note

Legacy migration artifacts under `TraderSpec/` remain available during cutover, but new requirements work should be authored in numbered root `specs/` feature directories.
