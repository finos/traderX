---
title: Learning Paths
---

# TraderX Learning Graph

This page maps the current state progression and points to canonical SpecKit artifacts.

> [!WARNING]
> `docs/guide/**` is deprecated and retained for historical context only.
> Canonical decision records now live in `docs/adr/**` using MADR format.

## State Map

| Level | State ID | Spec Pack | Generated Code Snapshot |
|---|---|---|---|
| 1 | `001-baseline-uncontainerized-parity` | `/specs/baseline-uncontainerized-parity` | `codex/generated-state-001-baseline-uncontainerized-parity` |
| 2 | `002-edge-proxy-uncontainerized` | `/specs/edge-proxy-uncontainerized` | `codex/generated-state-002-edge-proxy-uncontainerized` |
| 3 | `003-containerized-compose-runtime` | `/specs/containerized-compose-runtime` | `codex/generated-state-003-containerized-compose-runtime` |
| 4 | `004-kubernetes-runtime` | `/specs/kubernetes-runtime` | `codex/generated-state-004-kubernetes-runtime` |
| 5 | `005-radius-kubernetes-platform` | `/specs/radius-kubernetes-platform` | `codex/generated-state-005-radius-kubernetes-platform` |
| 6+ | planned learning-path states | future `specs/NNN-*` packs | future generated snapshots |

## Current Navigation

- State docs map: `/docs/spec-kit/state-docs`
- Visual graph: `/docs/spec-kit/visual-learning-graphs`
- Transition planning: `/docs/spec-kit/spec-kit-learning-path-strategy`
- State generation plan: `/docs/spec-kit/state-transition-generation-plan`

## Legacy Guides by Level (Deprecated)

## Level 0

- `learn-guide-index` -> `docs/guide/README.md`
- `learn-strategy` -> `docs/guide/strategy.md`

## Level 1

- `learn-learning-path-architecture` -> `docs/guide/learning-path-architecture.md`

## Level 2

- `learn-implementation-roadmap` -> `docs/guide/implementation-roadmap.md`

## Level 3

- `learn-track-definitions` -> `docs/guide/track-definitions.md`

## Level 4

- `learn-maintenance-strategy` -> `docs/guide/maintenance-strategy.md`

## Level 5
- Legacy guide ADR mappings are deprecated; use the active MADR ADR list below.

## Suggested Start Routes

- Baseline-first: `001` -> `002` -> `003`
- Architecture-first: `state-docs` -> `visual-learning-graphs` -> state spec packs
- Spec-first full rebuild: `docs/spec-kit/index` -> `docs/spec-kit/spec-kit-learning-path-strategy` -> `docs/spec-kit/visual-learning-graphs`
- Future enhancement: a dedicated state/learning-path navigator will be added later as a separate capability.

## Active Project ADRs

- [ADR-001 Adopt GitHub Spec Kit](/docs/adr/001-adopt-github-speckit)
- [ADR-002 Generated State Branching Strategy](/docs/adr/002-generated-state-branching-strategy)
- [ADR-003 Intentional Legacy-Shaped Baseline](/docs/adr/003-baseline-intentionally-simplistic-legacy-shaped)
- [ADR-004 Lightweight Baseline Infrastructure and Replaceability](/docs/adr/004-prefer-lightweight-default-infra-and-swappable-components)

## Runbook

```bash
# Validate guide front matter
tools/validate-frontmatter.sh

# Validate canonical spec/readiness coverage
bash pipeline/speckit/validate-root-spec-kit-gates.sh
bash pipeline/speckit/validate-speckit-readiness.sh
bash pipeline/verify-spec-coverage.sh
```
