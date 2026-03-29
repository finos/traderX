---
title: Run Generated Baseline
---

# Run Generated Baseline

This is the canonical runbook for the base uncontainerized generated runtime.

## Regenerate All Base Components

```bash
bash pipeline/generate-reference-data-specfirst.sh
bash pipeline/generate-database-specfirst.sh
bash pipeline/generate-people-service-specfirst.sh
bash pipeline/generate-account-service-specfirst.sh
bash pipeline/generate-position-service-specfirst.sh
bash pipeline/generate-trade-feed-specfirst.sh
bash pipeline/generate-trade-processor-specfirst.sh
bash pipeline/generate-trade-service-specfirst.sh
bash pipeline/generate-web-front-end-angular-specfirst.sh
```

## Start Full Overlay Stack

```bash
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./scripts/start-base-uncontainerized-generated.sh
```

Optional if dependencies are already cached:

```bash
TRADERSPEC_SKIP_NETWORK_CHECK=1 CORS_ALLOWED_ORIGINS=http://localhost:18093 ./scripts/start-base-uncontainerized-generated.sh
```

## Dry Run

```bash
./scripts/start-base-uncontainerized-generated.sh --dry-run
```

## Smoke Test Suite

```bash
./scripts/test-reference-data-overlay.sh
./scripts/test-database-overlay.sh
./scripts/test-people-service-overlay.sh
./scripts/test-account-service-overlay.sh
./scripts/test-position-service-overlay.sh
./scripts/test-trade-feed-overlay.sh
./scripts/test-trade-processor-overlay.sh
./scripts/test-trade-service-overlay.sh
./scripts/test-web-angular-overlay.sh
```

## Stop

```bash
./scripts/stop-base-uncontainerized-generated.sh
```
