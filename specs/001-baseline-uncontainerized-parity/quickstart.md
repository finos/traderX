# Quickstart: Baseline Uncontainerized Parity

## 1) Regenerate Baseline Components

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

## 2) Start Full Generated Overlay Stack

```bash
./TraderSpec/codebase/scripts/stop-base-uncontainerized-hydrated.sh
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

## 3) Run Baseline Smoke Checks

```bash
./TraderSpec/codebase/scripts/test-reference-data-overlay.sh
./TraderSpec/codebase/scripts/test-database-overlay.sh
./TraderSpec/codebase/scripts/test-people-service-overlay.sh
./TraderSpec/codebase/scripts/test-account-service-overlay.sh
./TraderSpec/codebase/scripts/test-position-service-overlay.sh
./TraderSpec/codebase/scripts/test-trade-feed-overlay.sh
./TraderSpec/codebase/scripts/test-trade-processor-overlay.sh
./TraderSpec/codebase/scripts/test-trade-service-overlay.sh
./TraderSpec/codebase/scripts/test-web-angular-overlay.sh
```

## 4) Run Closeness Comparison Gate

```bash
bash TraderSpec/pipeline/speckit/compare-all-component-generation.sh HEAD --allow-differences
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
