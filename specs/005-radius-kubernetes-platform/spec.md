# Feature Specification: Radius Platform on Kubernetes

**Feature Branch**: `005-radius-kubernetes-platform`  
**Created**: 2026-03-29  
**Status**: Planned  
**Input**: Transition delta from `004-kubernetes-runtime`

## User Stories

- As a platform engineer, I want Radius application/resource definitions layered on the Kubernetes baseline.
- As a maintainer, I want this state to remain independent from the Tilt dev-loop path.
- As a developer, I want no functional regressions while platform abstractions are introduced.

## Functional Requirements

- FR-00501: Baseline flows F1-F6 remain behaviorally compatible with state `004`.
- FR-00502: API routes and payload contracts remain unchanged unless explicitly declared in this pack.

## Non-Functional Requirements

- NFR-00501: Radius model artifacts are introduced as the primary deployment abstraction for this state.
- NFR-00502: Kubernetes remains the runtime substrate inherited from state `004`.
- NFR-00503: This state is independent of Tilt workflows and does not require Tilt assets.

## Success Criteria

- SC-00501: Generation hook and smoke test paths are implemented for Radius-based deployment artifacts.
- SC-00502: Generated snapshot branch and tag strategy are defined in state catalog.
- SC-00503: State topology/docs clearly identify this state as a sibling (not parent/child) of `006`.
