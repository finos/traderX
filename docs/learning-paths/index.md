---
title: Learning Paths
---

# TraderX Learning Graph

This page maps guides to implementation states and provides a quick start order.

## State Map

| Level | State ID | Folder |
|---|---|---|
| 0 | `00-monolith` | `states/00-monolith` |
| 1 | `01-basic-microservices` | `states/01-basic-microservices` |
| 2 | `02-containerized` | `states/02-containerized` |
| 3 | `03-service-mesh` | `states/03-service-mesh` |
| 4 | `04-contract-driven` | `states/04-contract-driven` |
| 5 | `05-ai-first` | `states/05-ai-first` |

## Guides by Level

## Level 0

- `learn-guide-index` -> `docs/guide/README.md`
- `learn-strategy` -> `docs/guide/strategy.md`

## Level 1

- `learn-learning-path-architecture` -> `docs/guide/learning-path-architecture.md`
- `learn-adr-001-multi-branch-state-management` -> `docs/guide/adr/001-multi-branch-state-management.md`

## Level 2

- `learn-implementation-roadmap` -> `docs/guide/implementation-roadmap.md`
- `learn-adr-002-milestone-state-selection` -> `docs/guide/adr/002-milestone-state-selection.md`

## Level 3

- `learn-track-definitions` -> `docs/guide/track-definitions.md`

## Level 4

- `learn-maintenance-strategy` -> `docs/guide/maintenance-strategy.md`
- `learn-adr-003-dependency-management-strategy` -> `docs/guide/adr/003-dependency-management-strategy.md`
- `learn-adr-004-testing-strategy-across-states` -> `docs/guide/adr/004-testing-strategy-across-states.md`

## Level 5

- `learn-adr-005-documentation-generation` -> `docs/guide/adr/005-documentation-generation.md`

## Suggested Start Routes

- Beginner: Level 0 -> Level 1 -> Level 2
- Mesh-focused: Level 2 -> Level 3 (`states/03-service-mesh/solo-demo`)
- Contract-focused: Level 2 -> Level 4
- Agent-focused: Level 4 -> Level 5
- Spec-first full rebuild: `docs/traderspec/index` -> `docs/traderspec/spec-layering` -> `docs/traderspec/visual-learning-graphs`

## Runbook

```bash
# Validate guide front matter
tools/validate-frontmatter.sh

# Run all state checks
find states -maxdepth 3 -type f -name "verify.sh" -print -exec {} \;
```
