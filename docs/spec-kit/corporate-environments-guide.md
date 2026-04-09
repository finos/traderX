---
title: Corporate Environments Guide
---

# Corporate Environments Guide

This guide defines how enterprises can extend TraderX privately without pushing corporate-specific changes upstream.

Detailed implementation contracts:

- [Custom Overlay Architecture](/docs/spec-kit/custom-overlay-architecture)
- [Custom Environments Guide](/docs/spec-kit/custom-environments-guide)

## Current Repository Baseline

As of this branch (`feature/agentic-renovation`), TraderX is already set up with:

- canonical authoring in `specs/**` and `.specify/**`
- generated code publish model in `code/generated-state-*` branches
- catalog-driven publish metadata in `catalog/state-catalog.json`
- generation/publish automation in `pipeline/generate-state.sh` and `pipeline/publish-generated-state-branch.sh`

Important current constraints:

- a state must be present in `catalog/state-catalog.json`
- `generation.mode` must be `implemented`
- publish branch must match `code/generated-state-*`
- working tree must be clean before publish

## Decision

Use a separate corporate overlay repository as the runtime implementation model, and keep this TraderX repository upstream-canonical.

Do not place corporate-only state definitions, transforms, secrets, proxy config, or private runtime assumptions into upstream TraderX.

## Recommended Corporate Repository Shape

```text
traderx-corporate-overlay/
  upstream/traderX/                  # git submodule pinned to upstream commit
  corporate/catalog/state-catalog.json
  corporate/profiles/
    corporate-internal.yaml
    public-dev.yaml
  corporate/states/
    corp-001-internal-build/
    corp-002-podman-runtime/
  corporate/transforms/
  corporate/runtime/
  scripts/
  docs/
```

Bootstrap starter included in this repository:

- `examples/corporate-overlay-template/`

## State and Branch Policy

Define three classes:

1. `mirrored-upstream`: generate and publish selected upstream states in your private remote.
2. `suppressed-upstream`: skip states that are not runnable or not approved for corporate runtime.
3. `internal-only`: generate additional corporate states (`corp-*`) only in the corporate repository.

Example policy file in corporate overlay repo (`corporate/profiles/corporate-internal.yaml`):

```yaml
profile: corporate-internal
upstreamPin: feature/agentic-renovation
mirroredUpstreamStates:
  - 003-containerized-compose-runtime
  - 006-observability-lgtm-compose
  - 008-order-management-matcher
suppressedUpstreamStates:
  - id: 009-kubernetes-runtime
    reason: "Cluster runtime not approved in this environment"
internalStates:
  - id: corp-001-managed-postgres-runtime
    basedOn: 003-containerized-compose-runtime
    publishBranch: code/generated-state-corp-001-managed-postgres-runtime
  - id: corp-002-internal-docs-branding
    basedOn: corp-001-managed-postgres-runtime
    publishBranch: code/generated-state-corp-002-internal-docs-branding
```

## Internal Docs Portal Strategy

Corporate overlays should run an internal docs portal that:

- clearly marks internal distribution with a persistent warning banner
- shows only sanctioned internal learning-path branches
- distinguishes mirrored upstream states from internal-only `corp-*` states
- publishes a corporate learning graph derived from internal policy, not all public branches

The bootstrap template includes:

- `examples/corporate-overlay-template/corporate/catalog/sanctioned-learning-graph.yaml`
- `examples/corporate-overlay-template/corporate/docs/internal-learning-graph.md`
- `examples/corporate-overlay-template/corporate/docs/internal-docs-portal.md`

For docs-platform upgrade safety (Docusaurus/plugins/Webpack), follow:

- `/docs/spec-kit/spec-kit-workflow#docusaurus-ci-compatibility`

## Upstream Sync Workflow

1. Update submodule pin to a tested upstream commit.
2. Regenerate only profile-approved states.
3. Publish private generated-state branches to the corporate remote.
4. Run corporate validation gates.
5. Promote the new pin only after generation + runtime validation succeeds.

Bootstrap commands:

```bash
mkdir traderx-corporate-overlay
cd traderx-corporate-overlay
git init
git submodule add -b feature/agentic-renovation https://github.com/finos/traderX.git upstream/traderX
git submodule update --init --recursive
```

Refresh upstream pin:

```bash
git -C upstream/traderX fetch origin
git -C upstream/traderX checkout feature/agentic-renovation
git -C upstream/traderX pull --ff-only
git add upstream/traderX
git commit -m "chore: bump TraderX upstream pin"
```

Generate from upstream submodule directly into corporate overlay output root:

```bash
TRADERX_GENERATED_ROOT=/path/to/traderx-corporate-overlay/generated \
  bash upstream/traderX/pipeline/generate-state.sh 003-containerized-compose-runtime
```

Generated state output includes a local runtime harness at:

- `/path/to/traderx-corporate-overlay/generated/code/target-generated/scripts`
- `/path/to/traderx-corporate-overlay/generated/code/target-generated/RUN_FROM_GENERATED.md`

This lets corporate overlays run start/stop/status from generated artifacts directly,
while upstream root scripts can forward to those local harness scripts.

## Generation Rules For Agents and Humans

- Never modify `upstream/traderX` for corporate-only requirements.
- Never hand-edit generated runtime outputs.
- Encode persistent corporate deltas as profile/state/transform artifacts in the corporate repo.
- Preserve explicit lineage (`previous`) for every corporate state.
- Keep generation reproducible from pinned upstream commit + corporate artifacts.

## Why This Fits TraderX Today

- Upstream already cleanly separates canonical specs from published generated branches.
- Current publish tooling already enforces branch naming and implemented-state controls.
- Corporate suppression/addition is better represented as a profile-level policy in a separate repo, not as upstream catalog edits.

## Transitional Guidance Inside Upstream TraderX

This document is the upstream reference contract.
Actual corporate runtime implementation should live outside this repository.
