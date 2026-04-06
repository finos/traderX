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
bash pipeline/generate-state.sh 003-containerized-compose-runtime
bash pipeline/generate-state.sh 006-observability-lgtm-compose
bash pipeline/generate-state.sh 011-platform-convergence-c3
```

Run examples:

```bash
# 001 (uncontainerized)
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./scripts/start-base-uncontainerized-generated.sh

# 003 (compose)
./scripts/start-state-003-containerized-generated.sh

# 006 (compose + observability)
./scripts/start-state-006-observability-lgtm-compose-generated.sh

# 009 (kubernetes)
./scripts/start-state-009-kubernetes-runtime-generated.sh --provider kind
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
