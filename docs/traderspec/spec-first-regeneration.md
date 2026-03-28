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
- `TraderSpec/catalog/component-spec.csv`

## Commands

```bash
./TraderSpec/pipeline/validate-regeneration-readiness.sh
./TraderSpec/pipeline/generate-from-spec.sh
```

## Run Generated Target

```bash
./TraderSpec/codebase/scripts/run-specfirst-generated-codebase.sh
```

## Output Locations

- `TraderSpec/codebase/target-generated-specfirst`:
  synthesized output assembled by `generate-from-spec.sh` and used by `run-specfirst-generated-codebase.sh`.
- `TraderSpec/codebase/generated-components/*-specfirst`:
  per-component generated sources produced by component generators.
- `TraderSpec/codebase/target-generated`:
  runtime assembly target used by base startup scripts and overlay switching.

## Comparison (Optional)

```bash
bash TraderSpec/pipeline/speckit/compare-all-component-generation.sh HEAD --allow-differences
```

## Recommended Operator Guide

Use `/docs/traderspec/spec-kit-generation-guide` for the full baseline generate/run/validate sequence.
