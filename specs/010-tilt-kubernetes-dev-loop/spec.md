# Feature Specification: Tilt Local Dev on Kubernetes

**Feature Branch**: `010-tilt-kubernetes-dev-loop`  
**Created**: 2026-03-29  
**Status**: Implemented  
**Input**: Transition delta from `009-kubernetes-runtime`

## User Stories

- As a developer, I want a fast local Kubernetes inner loop using Tilt.
- As a maintainer, I want this state to stay independent from the Radius path.
- As a developer, I want functional behavior to remain compatible while dev tooling improves.

## Functional Requirements

- FR-01001: Baseline flows F1-F6 remain behaviorally compatible with state `009-kubernetes-runtime`.
- FR-01002: API routes and payload contracts remain unchanged unless explicitly declared in this pack.

## Non-Functional Requirements

- NFR-01001: Tilt manifests/config become the canonical local developer orchestration for this state.
- NFR-01002: Kubernetes remains the runtime substrate inherited from state `009-kubernetes-runtime`.
- NFR-01003: This state does not require Radius artifacts.

## Success Criteria

- SC-01001: Generation hook and smoke test paths are implemented for Tilt-focused assets.
- SC-01002: Generated snapshot branch and tag strategy are defined in state catalog.
- SC-01003: State topology/docs clearly identify this state as a sibling (not parent/child) of `012-radius-kubernetes-platform`.
