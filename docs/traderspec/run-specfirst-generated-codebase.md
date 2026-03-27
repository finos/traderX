---
title: Run Spec-First Generated Codebase
---

# Run Spec-First Generated Codebase

This runs the **spec-first generated target** (`target-generated-specfirst`) with Angular-only UI scope.

## One Command Run

From repo root:

```bash
./TraderSpec/codebase/scripts/run-specfirst-generated-codebase.sh
```

What this does:

1. validates regeneration readiness
2. generates from specs with spec-mapped hydration
3. prepares compose layout in generated target
4. starts stack via generated target compose file

## Stop

```bash
./TraderSpec/codebase/scripts/stop-specfirst-generated-codebase.sh
```

## Manual Step-by-Step

```bash
./TraderSpec/pipeline/validate-regeneration-readiness.sh
./TraderSpec/pipeline/generate-from-spec.sh --hydrate-from-source
./TraderSpec/codebase/scripts/prepare-specfirst-layout.sh
docker compose -f TraderSpec/codebase/target-generated-specfirst/docker-compose.yml up -d --build
```
