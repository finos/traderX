---
title: Generated State Branches
---

# Generated State Branches

TraderX keeps the canonical source of truth in `specs/**` + `.specify/**`, and publishes code-only snapshots in dedicated `code/generated-state-*` branches.

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
- `LEARNING.md`
- `docs/learning/*` generated learning artifacts (component list, system design, architecture, diagram)

These files record:

- current state id/title
- prior states and known next states
- source branch/commit used to generate snapshot
- generation timestamp
- state-oriented learning links back to canonical docs/specs

Canonical portal learning guides live at:

- `/docs/learning`

## Publish The Baseline Generated Branch

From a clean working tree:

```bash
bash pipeline/publish-generated-state-branch.sh 001-baseline-uncontainerized-parity --push
```

When adding or updating a state, publish the lineage neighborhood so adjacent
branches get refreshed lineage/compare links:

```bash
bash pipeline/publish-generated-state-neighborhood.sh <state-id> --push
```

Default branch target for baseline:

- `code/generated-state-001-baseline-uncontainerized-parity`

State `002-edge-proxy-uncontainerized` now uses:

- generation: `bash pipeline/generate-state.sh 002-edge-proxy-uncontainerized`
- runtime: `./scripts/start-state-002-edge-proxy-generated.sh`
- publish branch: `code/generated-state-002-edge-proxy-uncontainerized`

Publish branch snapshot:

```bash
bash pipeline/publish-generated-state-branch.sh 002-edge-proxy-uncontainerized --push
```

State `003-containerized-compose-runtime` now uses:

- generation: `bash pipeline/generate-state.sh 003-containerized-compose-runtime`
- runtime: `./scripts/start-state-003-containerized-generated.sh` (NGINX ingress on `http://localhost:8080`)
- publish branch: `code/generated-state-003-containerized-compose-runtime`

Publish branch snapshot:

```bash
bash pipeline/publish-generated-state-branch.sh 003-containerized-compose-runtime --push
```

Current published generated branches:

- `code/generated-state-001-baseline-uncontainerized-parity`
- `code/generated-state-002-edge-proxy-uncontainerized`
- `code/generated-state-003-containerized-compose-runtime`

## How To Add A New State

1. Scaffold the feature pack:

```bash
bash pipeline/scaffold-state-pack.sh <NNN-state-name> --title "<Title>" --previous <prior-state-id> --track <devex|nonfunctional|functional>
```

2. Add/update requirements, plan, tasks, contracts, and traceability for the new state.
3. Confirm state entry in `catalog/state-catalog.json` with:
   - `previous` lineage
   - publish branch/tag conventions
   - `generation.mode=planned` until implemented
4. Implement state generation pipeline and change `generation.mode` to `implemented`.
5. Publish generated branch + tag with validation evidence.

Recommended publish sequence after implementing a new state:

1. `bash pipeline/publish-generated-state-neighborhood.sh <state-id> --push`
2. `bash pipeline/publish-generated-state-tree.sh --push` (optional full refresh)

This keeps specification and generated code distribution clearly separated while preserving state-to-state continuity.
