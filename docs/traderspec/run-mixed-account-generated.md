---
title: Run Mixed Mode (Generated Account-Service)
---

# Run Mixed Mode (Generated Account-Service)

This mode runs the baseline stack with:

- generated `reference-data`
- generated `database`
- generated `people-service`
- generated `account-service`
- hydrated versions of remaining components

## Regenerate Generated Components

```bash
bash TraderSpec/pipeline/generate-reference-data-specfirst.sh
bash TraderSpec/pipeline/generate-database-specfirst.sh
bash TraderSpec/pipeline/generate-people-service-specfirst.sh
bash TraderSpec/pipeline/generate-account-service-specfirst.sh
```

## Start Mixed Mode

```bash
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --overlay-reference-generated --overlay-database-generated --overlay-people-generated --overlay-account-generated
```

If Gradle dependencies are already cached and you need to bypass network preflight checks:

```bash
TRADERSPEC_SKIP_NETWORK_CHECK=1 CORS_ALLOWED_ORIGINS=http://localhost:18093 ./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --overlay-reference-generated --overlay-database-generated --overlay-people-generated --overlay-account-generated
```

## Dry Run

```bash
./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --dry-run --overlay-reference-generated --overlay-database-generated --overlay-people-generated --overlay-account-generated
```

## Smoke Test

```bash
./TraderSpec/codebase/scripts/test-account-service-overlay.sh
```

## Stop

```bash
./TraderSpec/codebase/scripts/stop-base-uncontainerized-hydrated.sh
```
