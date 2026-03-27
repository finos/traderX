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

- `/traderspec-specs/` (navbar: **TraderSpec Specs**)
- `docs/traderspec/baseline-vs-parity` for baseline vs parity model
- `docs/traderspec/run-specfirst-generated-codebase` for runnable spec-first flow
- `docs/traderspec/spec-migration-journey` for the end-to-end migration TODO and progress
- `docs/traderspec/run-base-uncontainerized-hydrated` for phase-2 base runtime scripts
- `docs/traderspec/run-mixed-reference-generated` for phase-4 mixed mode with generated `reference-data`
- `docs/traderspec/run-mixed-database-generated` for the next mixed mode with generated `database`
- `docs/traderspec/run-mixed-people-generated` for mixed mode with generated `people-service` + generated `database` + generated `reference-data`
- `docs/traderspec/run-mixed-account-generated` for mixed mode with generated `account-service` + generated `people-service` + generated `database` + generated `reference-data`
- `docs/traderspec/run-mixed-position-generated` for mixed mode with generated `position-service` + previously cut-over generated services
- `docs/traderspec/run-mixed-trade-feed-generated` for mixed mode with generated `trade-feed` + previously cut-over generated services
- `docs/traderspec/run-mixed-trade-processor-generated` for mixed mode with generated `trade-processor` + previously cut-over generated services
- `docs/traderspec/run-mixed-trade-service-generated` for mixed mode with generated `trade-service` + previously cut-over generated services
- `docs/traderspec/run-mixed-web-angular-generated` for mixed mode with generated Angular web frontend + previously cut-over generated services
- `docs/traderspec/component-cutover-matrix` for phase-5 generated vs hydrated cutover tracking
