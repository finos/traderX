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

Parity is a copied reference snapshot of the existing implementation.

Use it for:

- behavior comparison
- drift detection
- confidence checks while migrating to generated implementation

Do not use parity copy as the long-term generation input.

## Current Pipeline

Spec-first generation:

```bash
./TraderSpec/pipeline/validate-regeneration-readiness.sh
./TraderSpec/pipeline/generate-from-spec.sh
```

Reference snapshot (optional comparator):

```bash
./TraderSpec/pipeline/generate-baseline-from-current.sh
```
