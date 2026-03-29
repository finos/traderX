# Feature Specification: Tilt Local Dev on Kubernetes

**Feature Branch**: `006-tilt-kubernetes-dev-loop`  
**Created**: 2026-03-29  
**Status**: Implemented  
**Input**: Transition delta from `004-kubernetes-runtime`

## User Stories

- As a developer, I want a fast local Kubernetes inner loop using Tilt.
- As a maintainer, I want this state to stay independent from the Radius path.
- As a developer, I want functional behavior to remain compatible while dev tooling improves.

## Functional Requirements

- FR-00601: Baseline flows F1-F6 remain behaviorally compatible with state `004`.
- FR-00602: API routes and payload contracts remain unchanged unless explicitly declared in this pack.

## Non-Functional Requirements

- NFR-00601: Tilt manifests/config become the canonical local developer orchestration for this state.
- NFR-00602: Kubernetes remains the runtime substrate inherited from state `004`.
- NFR-00603: This state does not require Radius artifacts.

## Success Criteria

- SC-00601: Generation hook and smoke test paths are implemented for Tilt-focused assets.
- SC-00602: Generated snapshot branch and tag strategy are defined in state catalog.
- SC-00603: State topology/docs clearly identify this state as a sibling (not parent/child) of `005`.
