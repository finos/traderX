---
title: Spec Kit Generation Guide
---

# Spec Kit Generation Guide

This guide describes how to regenerate TraderX code from specs and evolve between states.

## Source of Truth

- Spec framework: `/.specify/**`
- State packs: `/specs/NNN-*`
- State lineage and publish metadata: `/catalog/state-catalog.json`

Refresh all derived learning/state docs:

```bash
bash pipeline/refresh-state-docs.sh
```

## Generate and Run a State

Generate any state:

```bash
bash pipeline/generate-state.sh <state-id>
```

Typical examples:

```bash
bash pipeline/generate-state.sh 001-baseline-uncontainerized-parity
bash pipeline/generate-state.sh 004-containerized-compose-runtime
bash pipeline/generate-state.sh 007-observability-lgtm-compose
bash pipeline/generate-state.sh 012-platform-convergence-c3
```

## Override Generated Output Root

Generation defaults to `generated/` under the TraderX repository root.

You can override that location with:

```bash
TRADERX_GENERATED_ROOT=/absolute/path/to/generated bash pipeline/generate-state.sh <state-id>
```

When unset, behavior is unchanged.

## Generated Runtime Harness Requirement

Every generated state output now includes a local runtime harness under:

- `generated/code/target-generated/scripts`
- `generated/code/target-generated/RUN_FROM_GENERATED.md`

This harness is part of the generation contract and must include state-local
`start/stop/status` scripts (plus state smoke tests where available) so each
generated codebase is runnable with local scripts.

Root scripts under `/scripts` act as wrappers and may forward to the generated
local harness when present.

Harness sanity check:

```bash
./scripts/test-generated-runtime-harness.sh
```

Run examples:

```bash
# 001 (uncontainerized)
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./scripts/start-base-uncontainerized-generated.sh --build-only
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./scripts/start-base-uncontainerized-generated.sh

# 003 (compose)
./scripts/start-state-004-containerized-generated.sh
./scripts/start-state-004-containerized-generated.sh --skip-build

# 006 (compose + observability)
./scripts/start-state-007-observability-lgtm-compose-generated.sh
./scripts/start-state-007-observability-lgtm-compose-generated.sh --skip-build

# 009 (kubernetes)
./scripts/start-state-010-kubernetes-runtime-generated.sh --provider kind
./scripts/start-state-010-kubernetes-runtime-generated.sh --provider kind --skip-build
```

## Derived-State Implementation Pattern

For states `002+`:

1. Generate parent state.
2. Apply patch set from `specs/<state>/generation/patches/*.patch`.
3. Regenerate architecture docs.
4. Run state smoke tests + global gates.

Patch tooling:

```bash
bash pipeline/apply-state-patchset.sh <state-id> [target-root]
bash pipeline/create-state-patchset.sh <state-id> <parent-state-id> [target-path]
```

## Convergence-First Guidance

- Prefer starting new state work from convergence states:
  - `003` (`C0`)
  - `006` (`C1`)
  - `008` (`C2`)
  - `011` (`C3`)
- Keep `previous` single-parent.
- Use `dottedParents` only for convergence states.
- Update `system/convergence-rationale.md` when changing convergence states.

## Validation Gates

```bash
bash pipeline/refresh-state-docs.sh --check
bash pipeline/validate-state-pack-artifacts.sh
bash pipeline/verify-spec-coverage.sh
```

## Publish Code Snapshot Branches

```bash
bash pipeline/publish-generated-state-branch.sh <state-id> --push
```

Published branches include:

- `README.md` (lineage + convergence context)
- `STATE.md`
- `.traderx-state/state.json`
- `LEARNING.md`
