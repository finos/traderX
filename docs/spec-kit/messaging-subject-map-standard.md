---
title: Messaging Subject Map Standard
---

# Messaging Subject Map Standard

States that introduce, remove, or modify message-bus subject families MUST maintain `system/messaging-subject-map.md`.

## Scope

- Required for states `006+`.
- The map is cumulative for the state: list all active subject families in that state (not only the delta).

## Required Sections

Each file must contain:

- `## Subject Families`
- One bullet per subject family using the schema below.

## Entry Schema

```markdown
- `<subject family>`
  - producer: `<component>`
  - consumer: `<component>` (or `consumers:` list)
  - delivery: `point-to-point` | `broadcast`
  - wildcard: `yes` | `no` (include pattern when yes)
  - scope: `<global|per-account|per-ticker|...>`
  - payload: <summary of key fields/contracts>
```

## Authoring Rules

- Keep names and wildcard patterns aligned with runtime implementation.
- Keep payload summaries aligned with API/event contracts for that state.
- When a state adds subject families, update this file in that state pack.
- If a generated state contains `order-matcher`, the map must include:
  - `/accounts/<accountId>/orders`
  - `/orders`

## Validation

Generated-state contract validation (`pipeline/validate-generated-state-contracts.sh`) enforces required map presence and order-matcher subject-map coverage rules.
