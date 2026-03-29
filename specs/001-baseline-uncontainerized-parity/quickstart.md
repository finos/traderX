# Quickstart: Simple App - Base Uncontainerized App

## 1) Regenerate Baseline Components

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

## 2) Start Full Generated Stack

```bash
./scripts/stop-base-uncontainerized-generated.sh
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./scripts/start-base-uncontainerized-generated.sh
```

## 3) Run Baseline Smoke Checks

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

## 4) Run Closeness Comparison Gate

```bash
bash pipeline/speckit/compare-all-component-generation.sh HEAD --allow-differences
```

Review semantic categories and ensure there are no differences in:
- `source-code`
- `runtime-config`
- `api-contract`

## 5) Verify Spec Kit Prerequisites for This Feature

If current Git branch is not named as `001-*`, set `SPECIFY_FEATURE`:

```bash
SPECIFY_FEATURE=001-baseline-uncontainerized-parity bash .specify/scripts/bash/check-prerequisites.sh --json
```
