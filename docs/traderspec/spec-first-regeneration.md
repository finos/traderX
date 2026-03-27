---
title: Spec-First Regeneration
---

# Spec-First Regeneration

This flow generates implementation artifacts from requirements and technical specs, not from source copying.

## Inputs

- `TraderSpec/foundation/00-traditional-to-cloud-native/specs/05-functional-requirements-detailed.md`
- `TraderSpec/foundation/00-traditional-to-cloud-native/specs/06-technical-specifications.md`
- `TraderSpec/foundation/00-traditional-to-cloud-native/specs/07-ui-requirements-detailed.md`
- `TraderSpec/foundation/00-traditional-to-cloud-native/specs/08-requirements-traceability-matrix.md`
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
