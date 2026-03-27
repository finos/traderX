---
title: Run Mixed Mode (Generated Database)
---

# Run Mixed Mode (Generated Database)

This mode runs the baseline stack with:

- generated `database` component from TraderSpec specs
- generated `reference-data` component (optional but recommended)
- hydrated versions of remaining components

## Regenerate Generated Components

```bash
bash TraderSpec/pipeline/generate-database-specfirst.sh
bash TraderSpec/pipeline/generate-reference-data-specfirst.sh
```

## Start Mixed Mode

```bash
./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --overlay-database-generated --overlay-reference-generated
```

## Dry Run

```bash
./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --dry-run --overlay-database-generated --overlay-reference-generated
```

## Smoke Test

```bash
./TraderSpec/codebase/scripts/test-database-overlay.sh
```

## Stop

```bash
./TraderSpec/codebase/scripts/stop-base-uncontainerized-hydrated.sh
```
