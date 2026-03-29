---
title: Baseline vs Parity
---

# Baseline vs Parity

## Baseline

Baseline is the specification source of truth:

- functional requirements
- non-functional requirements
- technical component matrix
- API/event contracts
- UI workflow requirements

Generation should consume these specs.

## Parity

Parity is behavioral equivalence verification against approved baseline contracts and flows.

Use it for:

- behavior comparison
- drift detection
- confidence checks while migrating to generated implementation

Do not use source-copy hydration as generation input.

## Current Pipeline

Spec-first generation:

```bash
./pipeline/validate-regeneration-readiness.sh
./pipeline/generate-from-spec.sh
```

Generation comparator (optional):

```bash
bash pipeline/speckit/compare-all-component-generation.sh HEAD --allow-differences
```
