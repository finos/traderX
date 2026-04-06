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

- `003-containerized-compose-runtime`

### C1

- `006-observability-lgtm-compose`

### C2

- `008-order-management-matcher`

### C3

- `011-platform-convergence-c3`

## Contribution Policy

- Prefer starting new state design from the nearest suitable convergence state.
- If you modify a convergence state, update that state’s `system/convergence-rationale.md`.
- Do not use dotted-line parents for non-convergence states.
- Keep `previous` single-parent for publish lineage.

## Canonical Sources

- State metadata: `catalog/state-catalog.json`
- Convergence governance ADR: `/docs/adr/008-convergence-state-model`
- Visual graph: `/docs/learning-paths`
