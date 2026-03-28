---
title: TraderSpec Overview
---

# TraderSpec

TraderSpec is the spec-driven operating model for TraderX.

The baseline state is intentionally **pre-Docker / pre-ingress**. From that state, we regenerate code from requirements and then evolve through learning-path overlays.

## Start Here

1. Read the Spec Kit portal:
   - `/docs/traderspec/spec-kit-portal`
2. Read the end-to-end generation workflow:
   - `/docs/traderspec/spec-kit-workflow`
3. Follow the operator runbook:
   - `/docs/traderspec/spec-kit-generation-guide`
4. Run and verify the generated baseline:
   - `/docs/traderspec/run-generated-overlays`
5. Review migration execution status and evidence:
   - `/traderspec-specs/migration-todo`
   - `/traderspec-specs/migration-blog`

## Learning Path Model

All tracks start from the same base state:

- DevEx track
- Non-Functional track
- Functional track

## Core Rules

- Baseline functional requirements are defined once.
- Non-functional tracks add only NFR overlays.
- Functional track can add new FRs, with compatibility constraints.

## Canonical Spec Sources

- Root Spec Kit scaffold: `/.specify/**`
- Root feature packs: `/specs/**`
- Current baseline feature pack: `specs/001-baseline-uncontainerized-parity`

## Docusaurus Entry Points

- Spec catalog: `/traderspec-specs/specs`
- Baseline pack home: `/traderspec-specs/specs/baseline-uncontainerized-parity/README`
- `.specify` constitution/templates: `/traderspec-specs/specify`
- OpenAPI explorer: `/traderspec-specs/api`
- Workflow guide: `/docs/traderspec/spec-kit-workflow`
- API explorer guide: `/docs/traderspec/api-explorer`
- Baseline vs parity semantics: `/docs/traderspec/baseline-vs-parity`
