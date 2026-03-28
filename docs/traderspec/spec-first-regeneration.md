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

Runnable generated target:

```bash
./TraderSpec/codebase/scripts/run-specfirst-generated-codebase.sh
```

Generated output lands at:

- `TraderSpec/codebase/target-generated-specfirst`

Reference comparator (optional):

- `TraderSpec/codebase/target-generated` (parity snapshot copy)
