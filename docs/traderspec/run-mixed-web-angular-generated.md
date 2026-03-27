---
title: Run Mixed Mode (Generated Web Frontend Angular)
---

# Run Mixed Mode (Generated Web Frontend Angular)

This mode runs the baseline stack with all base-case components generated, including the Angular UI.

## Regenerate Generated Components

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

## Start Mixed Mode

```bash
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --overlay-reference-generated --overlay-database-generated --overlay-people-generated --overlay-account-generated --overlay-position-generated --overlay-trade-feed-generated --overlay-trade-processor-generated --overlay-trade-service-generated --overlay-web-angular-generated
```

## Dry Run

```bash
./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --dry-run --overlay-reference-generated --overlay-database-generated --overlay-people-generated --overlay-account-generated --overlay-position-generated --overlay-trade-feed-generated --overlay-trade-processor-generated --overlay-trade-service-generated --overlay-web-angular-generated
```

## Smoke Test

```bash
./TraderSpec/codebase/scripts/test-web-angular-overlay.sh
```

## Branding Checks

Smoke test validates these branded assets are served:

- `assets/img/traderx-apple-touch-icon.png`
- `assets/img/traderx-icon.png`
- `assets/img/FINOS_Icon_White.png`

## Stop

```bash
./TraderSpec/codebase/scripts/stop-base-uncontainerized-hydrated.sh
```
