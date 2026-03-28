---
title: TraderSpec Overview
---

# TraderSpec

TraderSpec is a new root workspace at `TraderSpec/` for spec-driven delivery.

It starts from a **pre-Docker traditional baseline** and layers learning-path steps across:

- DevEx track
- Non-Functional track
- Functional track

## Key Design Rule

- Baseline functional requirements are defined once.
- Non-functional tracks add only NFR overlays.
- Functional track can add new FRs, with compatibility constraints.

## Where to Look

- `TraderSpec/foundation/00-traditional-to-cloud-native/specs`
- `TraderSpec/catalog/learning-paths.yaml`
- `TraderSpec/tracks/*/steps/*/spec.md`
- `TraderSpec/prompts/**`
- `TraderSpec/graphs/*.mmd`

## Full Spec Browser

The site now exposes the actual source specs directly under:

- `/traderspec-specs/` (navbar: **Spec Kit**)
- canonical root feature pack: `/traderspec-specs/specs/baseline-uncontainerized-parity/README`
- left sidebar sections: **System Requirements**, **Component Specs**, **Conformance Packs**
- `docs/traderspec/spec-kit-workflow` for the requirements-first GitHub Spec Kit model
- `docs/traderspec/spec-kit-portal` for the complete Spec Kit portal map (`specs/**`, `.specify/**`, migration docs)
- `docs/traderspec/baseline-vs-parity` for baseline vs parity model
- `docs/traderspec/run-specfirst-generated-codebase` for runnable spec-first flow
- `docs/traderspec/spec-migration-journey` for the end-to-end migration TODO and progress
- `docs/traderspec/run-base-uncontainerized-hydrated` for phase-2 base runtime scripts
- `docs/traderspec/run-generated-overlays` for consolidated overlay progression, commands, and smoke checks
- `docs/traderspec/component-cutover-matrix` for phase-5 generated vs hydrated cutover tracking
