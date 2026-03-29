# Feature Specification: Kubernetes Runtime Baseline

**Feature Branch**: `004-kubernetes-runtime`  
**Created**: 2026-03-29  
**Status**: Implemented  
**Input**: Transition delta from `003-containerized-compose-runtime`

## User Stories

- As a developer, I want one reproducible command flow that deploys TraderX into a local Kubernetes cluster.
- As a maintainer, I want Kubernetes manifests to be generated from explicit state specs, not handwritten ad hoc.
- As a platform engineer, I want runtime deltas (Compose -> Kubernetes) documented without changing baseline business behavior.

## Functional Requirements

- FR-401: Baseline flows F1-F6 SHALL remain behaviorally compatible with state `003`.
- FR-402: The browser entrypoint SHALL remain a single origin at `http://localhost:8080`.
- FR-403: Existing API path prefixes (`/account-service`, `/trade-service`, `/reference-data`, etc.) SHALL remain stable in this state.

## Non-Functional Requirements

- NFR-401: Runtime SHALL use Kubernetes (local Kind cluster default for reproducibility, with optional Minikube support for broader developer accessibility).
- NFR-402: The edge entrypoint SHALL use NGINX in-cluster proxying for UI/API/WebSocket traffic.
- NFR-403: Generated manifests SHALL be deterministic and derived from `system/kubernetes-runtime.spec.json`.
- NFR-404: Generated images SHALL be built from generated component source and loaded into the target cluster.
- NFR-405: Runtime topology and architecture SHALL be machine-documented in `system/runtime-topology.md` and `system/architecture.model.json`.

## Success Criteria

- SC-401: `bash pipeline/generate-state.sh 004-kubernetes-runtime` produces Kubernetes artifacts under `generated/code/target-generated/kubernetes-runtime`.
- SC-402: `./scripts/start-state-004-kubernetes-generated.sh` creates/uses a Kind cluster, applies manifests, and reaches `http://localhost:8080/health`.
- SC-403: `./scripts/test-state-004-kubernetes-runtime.sh` passes core ingress/API/UI smoke checks.
- SC-404: Catalog metadata marks state `004` as implemented with canonical runtime commands.
