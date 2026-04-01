---
title: Spec Kit Generation Guide
---

# Spec Kit Generation Guide

This guide explains how to regenerate TraderX from requirements, then iterate into later learning-path states.

## Why This Helps

- You can recreate a working baseline from specs without relying on legacy root source.
- Every state transition is explicit as FR/NFR deltas in `specs/NNN-*`.
- New contributors can start from a known state and replay evolution with predictable gates.

## Baseline Source of Truth

- Spec scaffold and constitution: `/.specify/**`
- Baseline feature pack: `specs/001-baseline-uncontainerized-parity/**`
- Contracts: `specs/001-baseline-uncontainerized-parity/contracts/**/openapi.yaml`
- State lineage + publish model: `catalog/state-catalog.json`

## Generate Baseline Components

```bash
bash pipeline/generate-state.sh 001-baseline-uncontainerized-parity
```

## Run the Generated Baseline

```bash
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./scripts/start-base-uncontainerized-generated.sh
```

## Validate Requirements-to-Behavior Fidelity

```bash
./pipeline/speckit/validate-speckit-readiness.sh
./pipeline/speckit/verify-spec-expressiveness.sh
bash pipeline/speckit/run-full-parity-validation.sh
```

## Move to the Next Learning-Path State

1. Scaffold the next numbered feature pack:

```bash
bash pipeline/scaffold-state-pack.sh <NNN-state-name> --title "<Title>" --previous <prior-state-id> --track <devex|nonfunctional|functional>
```

2. Carry forward baseline requirements and add only the intended deltas.
3. Update contracts and component requirements for affected services.
4. Regenerate only impacted components, then rerun conformance/parity gates.

This keeps progression reversible and auditable across DevEx, NFR, and functional tracks.

## State Generation Model (Patch-Set Overlays)

TraderX now uses two generation modes:

1. Baseline synthesis (state `001`): generate components from manifests/specs.
2. Derived states (`002+`): generate parent, then apply ordered patch sets from `specs/<state>/generation/patches/*.patch`.

Canonical patch apply helper:

```bash
bash pipeline/apply-state-patchset.sh <state-id> [target-root]
```

Patch capture helper (refresh a state patch from parent/child outputs):

```bash
bash pipeline/create-state-patchset.sh <state-id> [parent-state-id] [target-path]
```

Examples:

```bash
# Component-root overlay for state 002
bash pipeline/create-state-patchset.sh \
  002-edge-proxy-uncontainerized \
  001-baseline-uncontainerized-parity \
  generated/code/components

# Runtime-root overlay for state 007
bash pipeline/create-state-patchset.sh \
  007-messaging-nats-replacement \
  003-containerized-compose-runtime
```

This pattern keeps state deltas explicit, reviewable, and reusable by both humans and LLM-driven implementation workflows.

Current state-aware generation entrypoints:

- `bash pipeline/generate-state.sh 001-baseline-uncontainerized-parity`
- `bash pipeline/generate-state.sh 002-edge-proxy-uncontainerized`
- `bash pipeline/generate-state.sh 003-containerized-compose-runtime`
- `bash pipeline/generate-state.sh 004-kubernetes-runtime`
- `bash pipeline/generate-state.sh 005-radius-kubernetes-platform`
- `bash pipeline/generate-state.sh 006-tilt-kubernetes-dev-loop`

Architecture docs are generated from state-local models under `specs/*/system/architecture.model.json`:

- `bash pipeline/generate-state-architecture-doc.sh 001-baseline-uncontainerized-parity`
- `bash pipeline/generate-all-architecture-docs.sh`

Containerized runtime (state `003`) commands:

- `./scripts/start-state-003-containerized-generated.sh`
- `./scripts/status-state-003-containerized-generated.sh`
- `./scripts/test-state-003-containerized.sh`
- `./scripts/stop-state-003-containerized-generated.sh`
- ingress endpoint: `http://localhost:8080`

Kubernetes runtime (state `004`) commands:

- `./scripts/start-state-004-kubernetes-generated.sh --provider kind`
- `./scripts/status-state-004-kubernetes-generated.sh --provider kind`
- `./scripts/test-state-004-kubernetes-runtime.sh http://localhost:8080 traderx kind traderx-state-004`
- `./scripts/stop-state-004-kubernetes-generated.sh --provider kind`

Radius platform state (state `005`) commands:

- `./scripts/start-state-005-radius-kubernetes-platform-generated.sh --provider kind`
- `./scripts/status-state-005-radius-kubernetes-platform-generated.sh --provider kind`
- `./scripts/test-state-005-radius-kubernetes-platform.sh http://localhost:8080 traderx kind traderx-state-004`
- `./scripts/stop-state-005-radius-kubernetes-platform-generated.sh --provider kind`

Tilt local dev-loop state (state `006`) commands:

- `./scripts/start-state-006-tilt-kubernetes-dev-loop-generated.sh --provider kind`
- `./scripts/status-state-006-tilt-kubernetes-dev-loop-generated.sh --provider kind`
- `./scripts/test-state-006-tilt-kubernetes-dev-loop.sh http://localhost:8080 traderx kind traderx-state-004`
- `./scripts/stop-state-006-tilt-kubernetes-dev-loop-generated.sh --provider kind`

## Publish Code-Only Snapshot Branches

For consumers who want runnable code without the full spec authoring workspace, publish a generated-state branch:

```bash
bash pipeline/publish-generated-state-branch.sh 001-baseline-uncontainerized-parity --push
```

And for state `003`:

```bash
bash pipeline/publish-generated-state-branch.sh 003-containerized-compose-runtime --push
```

Published snapshot branches include:

- `STATE.md`
- `.traderx-state/state.json`
- `LEARNING.md`
- `docs/learning/component-list.md`
- `docs/learning/system-design.md`
- `docs/learning/software-architecture.md`
- `docs/learning/component-diagram.md`

These capture the current state id and lineage so users know exactly what state they are running and what came before it.
