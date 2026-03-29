---
title: Spec-First Regeneration
---

# Spec-First Regeneration

This flow generates implementation artifacts from Spec Kit requirements and technical specs, not from source copying.

## Inputs

- `specs/001-baseline-uncontainerized-parity/system/system-requirements.md`
- `specs/001-baseline-uncontainerized-parity/system/user-stories.md`
- `specs/001-baseline-uncontainerized-parity/system/acceptance-criteria.md`
- `specs/001-baseline-uncontainerized-parity/system/requirements-traceability.csv`
- `catalog/component-spec.csv`

## Commands

```bash
./pipeline/validate-regeneration-readiness.sh
./pipeline/generate-from-spec.sh
```

## Run Generated Target

```bash
./scripts/start-base-uncontainerized-generated.sh
```

## Output Locations

- `TraderSpec/codebase/generated-components/*-specfirst`:
  per-component generated sources produced by component generators.
- `TraderSpec/codebase/target-generated`:
  runtime assembly target created on demand by generated startup scripts.

## Comparison (Optional)

```bash
bash pipeline/speckit/compare-all-component-generation.sh HEAD --allow-differences
```

## Recommended Operator Guide

Use `/docs/traderspec/spec-kit-generation-guide` for the full baseline generate/run/validate sequence.
