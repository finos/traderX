---
title: Learning Paths
---

# TraderX Learning Graph

This page maps guides to implementation states and provides a quick start order.

> [!WARNING]
> `docs/guide/**` is deprecated and retained for historical context only.
> Canonical decision records now live in `docs/adr/**` using MADR format.

## State Map

| Level | State ID | Folder |
|---|---|---|
| 0 | `00-monolith` | `states/00-monolith` |
| 1 | `01-basic-microservices` | `states/01-basic-microservices` |
| 2 | `02-containerized` | `states/02-containerized` |
| 3 | `03-service-mesh` | `states/03-service-mesh` |
| 4 | `04-contract-driven` | `states/04-contract-driven` |
| 5 | `05-ai-first` | `states/05-ai-first` |

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

- Beginner: Level 0 -> Level 1 -> Level 2
- Mesh-focused: Level 2 -> Level 3 (`states/03-service-mesh/solo-demo`)
- Contract-focused: Level 2 -> Level 4
- Agent-focused: Level 4 -> Level 5
- Spec-first full rebuild: `docs/spec-kit/index` -> `docs/spec-kit/spec-kit-learning-path-strategy` -> `docs/spec-kit/visual-learning-graphs`

## Active Project ADRs (MADR)

- [ADR-001 Adopt GitHub Spec Kit](/docs/adr/001-adopt-github-speckit)
- [ADR-002 Generated State Branching Strategy](/docs/adr/002-generated-state-branching-strategy)
- [ADR-003 Intentional Legacy-Shaped Baseline](/docs/adr/003-baseline-intentionally-simplistic-legacy-shaped)
- [ADR-004 Lightweight Baseline Infrastructure and Replaceability](/docs/adr/004-prefer-lightweight-default-infra-and-swappable-components)

## Runbook

```bash
# Validate guide front matter
tools/validate-frontmatter.sh

# Run all state checks
find states -maxdepth 3 -type f -name "verify.sh" -print -exec {} \;
```
