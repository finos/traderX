---
title: Generated State Branches
---

# Generated State Branches

TraderX keeps the canonical source of truth in `specs/**` + `.specify/**`, and publishes code-only snapshots in dedicated `codex/generated-state-*` branches.

## Canonical State Definitions

Each state is defined in two places:

1. SpecKit feature pack: `specs/NNN-<state-name>/`
2. State catalog entry: `catalog/state-catalog.json`

The state catalog is the publish contract for generated snapshots:

- state id/title/status
- predecessor states (`previous`)
- generation readiness (`generation.mode`)
- default generated-state branch name
- release tag hint

## State Independence + Lineage

Each state must be buildable from its own feature pack without requiring branch-local edits.

Lineage is explicit through `previous` in `catalog/state-catalog.json`.

Generated branches include metadata files so consumers can always see provenance:

- `STATE.md`
- `.traderx-state/state.json`

These files record:

- current state id/title
- prior states and known next states
- source branch/commit used to generate snapshot
- generation timestamp

## Publish The Baseline Generated Branch

From a clean working tree:

```bash
bash pipeline/publish-generated-state-branch.sh 001-baseline-uncontainerized-parity --push
```

Default branch target for baseline:

- `codex/generated-state-001-baseline-uncontainerized-parity`

State `002-edge-proxy-uncontainerized` now uses:

- generation: `bash pipeline/generate-state.sh 002-edge-proxy-uncontainerized`
- runtime: `./scripts/start-state-002-edge-proxy-generated.sh`
- publish branch: `codex/generated-state-002-edge-proxy-uncontainerized`

Publish branch snapshot:

```bash
bash pipeline/publish-generated-state-branch.sh 002-edge-proxy-uncontainerized --push
```

## How To Add A New State

1. Create the feature pack under `specs/NNN-...`.
2. Add/update requirements, plan, tasks, contracts, and traceability for the new state.
3. Add a state entry in `catalog/state-catalog.json` with:
   - `previous` lineage
   - publish branch/tag conventions
   - `generation.mode=planned` until implemented
4. Implement state generation pipeline and change `generation.mode` to `implemented`.
5. Publish generated branch + tag with validation evidence.

This keeps specification and generated code distribution clearly separated while preserving state-to-state continuity.
