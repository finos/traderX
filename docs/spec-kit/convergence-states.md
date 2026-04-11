---
title: Convergence States
---

# Convergence States

TraderX uses explicit convergence checkpoints to keep multi-track evolution understandable and maintainable.

## Why Convergence States Exist

- They mark recommended jump-off points for new work.
- They keep track progression explicit without forcing multi-parent branch ancestry.
- They allow transition states to remain focused and incremental.

Publish lineage remains single-parent via `previous`.  
Convergence context is represented separately via `isConvergence`, `convergenceLevel`, and `dottedParents`.

## Current Convergence Levels

### C0

- `004-containerized-compose-runtime`

### C1

- `007-observability-lgtm-compose`

### C2

- `009-order-management-matcher`

### C3

- `012-platform-convergence-c3`

## Contribution Policy

- Prefer starting new state design from the nearest suitable convergence state.
- If you modify a convergence state, update that state’s `system/convergence-rationale.md`.
- Do not use dotted-line parents for non-convergence states.
- Keep `previous` single-parent for publish lineage.

## CI + Artifact Publishing Policy

Convergence states from `C1+` must include:

- container build/publish workflow (`.github/workflows/build-and-publish.yml`)
- generated run bundle artifacts for consuming GHCR images directly

GHCR image namespaces are convergence-level scoped:

- `C1`: `ghcr.io/finos/traderx-c1/<component>`
- `C2`: `ghcr.io/finos/traderx-c2/<component>`
- `C3`: `ghcr.io/finos/traderx-c3/<component>`

Use immutable commit-SHA tags plus a moving `latest` tag per namespace/component.

Reference: `/docs/spec-kit/generated-state-ci`

## Canonical Sources

- State metadata: `catalog/state-catalog.json`
- Convergence governance ADR: `/docs/adr/008-convergence-state-model`
- Visual graph: `/docs/learning-paths`
