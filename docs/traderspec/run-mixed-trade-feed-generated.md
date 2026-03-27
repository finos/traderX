---
title: Run Mixed Mode (Generated Trade-Feed)
---

# Run Mixed Mode (Generated Trade-Feed)

This mode runs the baseline stack with:

- generated `reference-data`
- generated `database`
- generated `people-service`
- generated `account-service`
- generated `position-service`
- generated `trade-feed`
- hydrated versions of remaining components

## Regenerate Generated Components

```bash
bash TraderSpec/pipeline/generate-reference-data-specfirst.sh
bash TraderSpec/pipeline/generate-database-specfirst.sh
bash TraderSpec/pipeline/generate-people-service-specfirst.sh
bash TraderSpec/pipeline/generate-account-service-specfirst.sh
bash TraderSpec/pipeline/generate-position-service-specfirst.sh
bash TraderSpec/pipeline/generate-trade-feed-specfirst.sh
```

## Start Mixed Mode

```bash
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --overlay-reference-generated --overlay-database-generated --overlay-people-generated --overlay-account-generated --overlay-position-generated --overlay-trade-feed-generated
```

## Dry Run

```bash
./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --dry-run --overlay-reference-generated --overlay-database-generated --overlay-people-generated --overlay-account-generated --overlay-position-generated --overlay-trade-feed-generated
```

## Smoke Test

```bash
./TraderSpec/codebase/scripts/test-trade-feed-overlay.sh
```

## Stop

```bash
./TraderSpec/codebase/scripts/stop-base-uncontainerized-hydrated.sh
```
