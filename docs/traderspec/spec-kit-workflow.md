---
title: GitHub Spec Kit Workflow
---

# GitHub Spec Kit Workflow

TraderSpec now uses a root-canonical GitHub Spec Kit layout:

Browse it in Docusaurus:

- `/traderspec-specs/specs/baseline-uncontainerized-parity/README`
- `/traderspec-specs/specs/baseline-uncontainerized-parity/system/system-requirements`
- `/traderspec-specs/specs/baseline-uncontainerized-parity/system/user-stories`
- `/traderspec-specs/specs/baseline-uncontainerized-parity/system/acceptance-criteria`
- `/traderspec-specs/specs/baseline-uncontainerized-parity/system/requirements-traceability`
- `/traderspec-specs/specify` (constitution + Spec Kit templates)

## Source Inputs For System Understanding

The system-level requirements and user stories are grounded in:

- `docs/overview.md`
- `docs/flows.md`
- `docs/README.md`
- `README.md`

## Spec Kit Layers

- `.specify/**`
- `specs/001-baseline-uncontainerized-parity/spec.md`
- `specs/001-baseline-uncontainerized-parity/plan.md`
- `specs/001-baseline-uncontainerized-parity/tasks.md`
- `specs/001-baseline-uncontainerized-parity/system/**`
- `specs/001-baseline-uncontainerized-parity/components/*.md`
- `specs/001-baseline-uncontainerized-parity/contracts/**/openapi.yaml`

## Validation

```bash
./TraderSpec/pipeline/speckit/validate-speckit-readiness.sh
./TraderSpec/pipeline/speckit/verify-spec-expressiveness.sh
bash TraderSpec/pipeline/speckit/compile-all-component-manifests.sh
./TraderSpec/pipeline/validate-regeneration-readiness.sh
./TraderSpec/pipeline/verify-spec-coverage.sh
```

## Generation

Each component generator now asserts Spec Kit readiness and component traceability before writing code.
Manifest-driven synthesis (compiled manifest + template) is now active for all baseline component generators.

Example:

```bash
bash TraderSpec/pipeline/generate-reference-data-specfirst.sh
bash TraderSpec/pipeline/generate-trade-service-specfirst.sh
```

## Full Parity Validation

Run end-to-end parity validation (generation + startup + all baseline smoke tests):

```bash
bash TraderSpec/pipeline/speckit/run-full-parity-validation.sh
```

## Legacy vs Spec Kit Generator Output Diff

To compare a single component generated output between a legacy script revision and current Spec Kit-driven generation:

```bash
bash TraderSpec/pipeline/speckit/compare-component-generation.sh <component-id> <legacy-ref>
```

Example:

```bash
bash TraderSpec/pipeline/speckit/compare-component-generation.sh reference-data HEAD
```

This runs generation in a temporary worktree at `<legacy-ref>`, runs current generation in your working tree, then diffs the generated directories.
