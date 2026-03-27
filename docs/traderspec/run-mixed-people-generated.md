---
title: Run Mixed Mode (Generated People-Service)
---

# Run Mixed Mode (Generated People-Service)

This mode runs the baseline stack with:

- generated `people-service` component from TraderSpec specs
- generated `database` component
- generated `reference-data` component
- hydrated versions of remaining components

## Regenerate Generated Components

```bash
bash TraderSpec/pipeline/generate-reference-data-specfirst.sh
bash TraderSpec/pipeline/generate-database-specfirst.sh
bash TraderSpec/pipeline/generate-people-service-specfirst.sh
```

## Start Mixed Mode

```bash
./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --overlay-reference-generated --overlay-database-generated --overlay-people-generated
```

## Dry Run

```bash
./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --dry-run --overlay-reference-generated --overlay-database-generated --overlay-people-generated
```

## Smoke Test

```bash
./TraderSpec/codebase/scripts/test-people-service-overlay.sh
```

## Stop

```bash
./TraderSpec/codebase/scripts/stop-base-uncontainerized-hydrated.sh
```
