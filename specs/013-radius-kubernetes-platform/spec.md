# Feature Specification: Radius Platform on Kubernetes

**Feature Branch**: `013-radius-kubernetes-platform`  
**Created**: 2026-03-29  
**Status**: Implemented  
**Input**: Transition delta from `012-platform-convergence-c3`

## User Stories

- As a platform engineer, I want Radius application/resource definitions layered on the Kubernetes baseline.
- As a maintainer, I want this state to build on the C3 platform baseline while adding Radius deployment abstractions.
- As a developer, I want no functional regressions while platform abstractions are introduced.

## Functional Requirements

- FR-01201: Baseline flows F1-F6 remain behaviorally compatible with state `012-platform-convergence-c3`.
- FR-01202: API routes and payload contracts remain unchanged unless explicitly declared in this pack.

## Non-Functional Requirements

- NFR-01201: Radius model artifacts are introduced as the primary deployment abstraction for this state.
- NFR-01202: Kubernetes remains the runtime substrate inherited from state `012-platform-convergence-c3`.
- NFR-01203: This state inherits the C3 baseline and adds Radius-specific platform artifacts as an optional deployment path.

## Success Criteria

- SC-01201: Generation hook and smoke test paths are implemented for Radius deployment artifacts.
- SC-01202: Generated snapshot branch and tag strategy are defined in state catalog.
- SC-01203: State topology/docs clearly identify this state as a child branch of `012-platform-convergence-c3`.
