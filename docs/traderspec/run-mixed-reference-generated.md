---
title: Run Mixed Mode (Generated Reference-Data)
---

# Run Mixed Mode (Generated Reference-Data)

This mode runs the baseline stack with:

- generated `reference-data` component from TraderSpec specs
- hydrated versions of the remaining components

## Start Mixed Mode

```bash
./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --overlay-reference-generated
```

## Dry Run

```bash
./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --dry-run --overlay-reference-generated
```

## Stop

```bash
./TraderSpec/codebase/scripts/stop-base-uncontainerized-hydrated.sh
```

## Generated Component Location

- `TraderSpec/codebase/generated-components/reference-data-specfirst`

## Regenerate Generated-Only Folder

```bash
bash TraderSpec/pipeline/generate-reference-data-specfirst.sh
```

## CORS

Generated `reference-data` enables CORS by default for this base state.
Optional override:

```bash
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --overlay-reference-generated
```

## Smoke Test

```bash
./TraderSpec/codebase/scripts/test-reference-data-overlay.sh
```
