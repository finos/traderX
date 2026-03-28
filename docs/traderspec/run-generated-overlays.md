---
title: Run Generated Overlays
---

# Run Generated Overlays

This is the consolidated runbook for overlay mode in the base uncontainerized state.

## Regenerate All Base Components

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

## Start Full Overlay Stack

```bash
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --overlay-reference-generated --overlay-database-generated --overlay-people-generated --overlay-account-generated --overlay-position-generated --overlay-trade-feed-generated --overlay-trade-processor-generated --overlay-trade-service-generated --overlay-web-angular-generated
```

Optional if dependencies are already cached:

```bash
TRADERSPEC_SKIP_NETWORK_CHECK=1 CORS_ALLOWED_ORIGINS=http://localhost:18093 ./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --overlay-reference-generated --overlay-database-generated --overlay-people-generated --overlay-account-generated --overlay-position-generated --overlay-trade-feed-generated --overlay-trade-processor-generated --overlay-trade-service-generated --overlay-web-angular-generated
```

## Dry Run

```bash
./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --dry-run --overlay-reference-generated --overlay-database-generated --overlay-people-generated --overlay-account-generated --overlay-position-generated --overlay-trade-feed-generated --overlay-trade-processor-generated --overlay-trade-service-generated --overlay-web-angular-generated
```

## Overlay Progression

| Stage | Overlay Flag Added | Smoke Test |
|---|---|---|
| 1 | `--overlay-reference-generated` | `./TraderSpec/codebase/scripts/test-reference-data-overlay.sh` |
| 2 | `--overlay-database-generated` | `./TraderSpec/codebase/scripts/test-database-overlay.sh` |
| 3 | `--overlay-people-generated` | `./TraderSpec/codebase/scripts/test-people-service-overlay.sh` |
| 4 | `--overlay-account-generated` | `./TraderSpec/codebase/scripts/test-account-service-overlay.sh` |
| 5 | `--overlay-position-generated` | `./TraderSpec/codebase/scripts/test-position-service-overlay.sh` |
| 6 | `--overlay-trade-feed-generated` | `./TraderSpec/codebase/scripts/test-trade-feed-overlay.sh` |
| 7 | `--overlay-trade-processor-generated` | `./TraderSpec/codebase/scripts/test-trade-processor-overlay.sh` |
| 8 | `--overlay-trade-service-generated` | `./TraderSpec/codebase/scripts/test-trade-service-overlay.sh` |
| 9 | `--overlay-web-angular-generated` | `./TraderSpec/codebase/scripts/test-web-angular-overlay.sh` |

## Stop

```bash
./TraderSpec/codebase/scripts/stop-base-uncontainerized-hydrated.sh
```
