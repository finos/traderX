---
title: Spec Kit Generation Guide
---

# Spec Kit Generation Guide

This guide explains how to regenerate TraderX from requirements, then iterate into later learning-path states.

## Why This Helps

- You can recreate a working baseline from specs without relying on legacy root source.
- Every state transition is explicit as FR/NFR deltas in `specs/NNN-*`.
- New contributors can start from a known state and replay evolution with predictable gates.

## Baseline Source of Truth

- Spec scaffold and constitution: `/.specify/**`
- Baseline feature pack: `specs/001-baseline-uncontainerized-parity/**`
- Contracts: `specs/001-baseline-uncontainerized-parity/contracts/**/openapi.yaml`

## Generate Baseline Components

```bash
bash TraderSpec/pipeline/generate-reference-data-specfirst.sh
bash TraderSpec/pipeline/generate-database-specfirst.sh
bash TraderSpec/pipeline/generate-people-service-specfirst.sh
bash TraderSpec/pipeline/generate-account-service-specfirst.sh
bash TraderSpec/pipeline/generate-position-service-specfirst.sh
bash TraderSpec/pipeline/generate-trade-feed-specfirst.sh
bash TraderSpec/pipeline/generate-trade-processor-specfirst.sh
bash TraderSpec/pipeline/generate-trade-service-specfirst.sh
bash TraderSpec/pipeline/generate-web-front-end-angular-specfirst.sh
```

## Run the Generated Baseline

```bash
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh \
  --overlay-reference-generated \
  --overlay-database-generated \
  --overlay-people-generated \
  --overlay-account-generated \
  --overlay-position-generated \
  --overlay-trade-feed-generated \
  --overlay-trade-processor-generated \
  --overlay-trade-service-generated \
  --overlay-web-angular-generated
```

## Validate Requirements-to-Behavior Fidelity

```bash
./TraderSpec/pipeline/speckit/validate-speckit-readiness.sh
./TraderSpec/pipeline/speckit/verify-spec-expressiveness.sh
bash TraderSpec/pipeline/speckit/run-full-parity-validation.sh
```

## Move to the Next Learning-Path State

1. Create the next numbered feature pack `specs/NNN-<state-name>/`.
2. Carry forward baseline requirements and add only the intended deltas.
3. Update contracts and component requirements for affected services.
4. Regenerate only impacted components, then rerun conformance/parity gates.

This keeps progression reversible and auditable across DevEx, NFR, and functional tracks.
