# Multi-State Generation Plan

This plan defines how TraderX evolves through numbered states with explicit convergence checkpoints.

## Objectives

- keep each transition reproducible from specs,
- keep generated branches compareable and publishable,
- isolate FR/NFR deltas per state,
- preserve a clear set of recommended jump-off points (`C0-C3`).

## Explicit State Inheritance Policy

- Every state inherits all functional and non-functional behavior from its `previous` lineage by default.
- A state may diverge from inherited behavior only when the feature pack declares an explicit conflict, replacement, or deprecation requirement.
- If no explicit conflict/replacement/deprecation is declared, generation, runtime scripts, smoke tests, and docs must keep inherited capabilities intact.
- Validation should verify inherited capabilities in downstream states to prevent accidental feature loss during runtime transitions.

## Transition Mechanics

1. Update target state pack (`spec.md`, `plan.md`, `tasks.md`, `system/**`).
2. Generate parent state.
3. Apply ordered patch set (`specs/<state>/generation/patches/*.patch`) for derived changes.
4. Regenerate architecture docs.
5. Run state smoke tests + global gates.
6. Publish code snapshot branch.

## Current Convergence-First Model

```mermaid
flowchart LR
  S001["001 Prelude"] --> S002["002 Prelude"]
  S002 --> C0["003 C0"]
  C0 --> A004["004 Postgres"]
  A004 --> A005["005 NATS"]
  A005 --> C1["006 C1 Observability"]
  C1 --> F007["007 Pricing"]
  F007 --> C2["008 C2 Order Mgmt"]
  C2 --> P009["009 Kubernetes"]
  P009 --> P010["010 Tilt"]
  P010 --> C3["011 C3 Platform Convergence"]
  P009 --> O012["012 Radius Optional"]
```

## Publish Model

- Canonical authoring stays in this branch (`specs/**`, `.specify/**`, pipeline/docs).
- Generated code snapshots are published to `code/generated-state-*` branches.
- Publish ancestry follows `previous` only.
- Dotted-line parents are docs lineage only.

## Required Governance for Convergence States

- `catalog/state-catalog.json` must carry convergence metadata.
- `system/convergence-rationale.md` must exist and be updated when convergence state content/metadata changes.
- CI gates must pass before publish.
- Convergence states `C1+` must include image build/publish CI and GHCR run-bundle artifacts (see `/docs/spec-kit/generated-state-ci`).

## Reference Commands

```bash
bash pipeline/refresh-state-docs.sh
bash pipeline/verify-spec-coverage.sh
bash pipeline/publish-generated-state-branch.sh <state-id> --push
```
