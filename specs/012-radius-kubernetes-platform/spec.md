# Feature Specification: Radius Platform on Kubernetes

**Feature Branch**: `012-radius-kubernetes-platform`  
**Created**: 2026-03-29  
**Status**: Implemented  
**Input**: Transition delta from `009-kubernetes-runtime`

## User Stories

- As a platform engineer, I want Radius application/resource definitions layered on the Kubernetes baseline.
- As a maintainer, I want this state to remain independent from the Tilt dev-loop path.
- As a developer, I want no functional regressions while platform abstractions are introduced.

## Functional Requirements

- FR-01201: Baseline flows F1-F6 remain behaviorally compatible with state `009-kubernetes-runtime`.
- FR-01202: API routes and payload contracts remain unchanged unless explicitly declared in this pack.

## Non-Functional Requirements

- NFR-01201: Radius model artifacts are introduced as the primary deployment abstraction for this state.
- NFR-01202: Kubernetes remains the runtime substrate inherited from state `009-kubernetes-runtime`.
- NFR-01203: This state is independent of Tilt workflows and does not require Tilt assets.

## Success Criteria

- SC-01201: Generation hook and smoke test paths are implemented for Radius deployment artifacts.
- SC-01202: Generated snapshot branch and tag strategy are defined in state catalog.
- SC-01203: State topology/docs clearly identify this state as a sibling branch of `010-tilt-kubernetes-dev-loop`.
