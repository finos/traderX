# Feature Specification: Kubernetes Runtime Baseline

**Feature Branch**: `010-kubernetes-runtime`  
**Created**: 2026-03-29  
**Status**: Implemented  
**Input**: Transition delta from `009-order-management-matcher`

## User Stories

- As a developer, I want one reproducible command flow that deploys TraderX into a local Kubernetes cluster.
- As a maintainer, I want Kubernetes manifests to be generated from explicit state specs, not handwritten ad hoc.
- As a platform engineer, I want runtime deltas (Compose -> Kubernetes) documented without changing baseline business behavior.

## Functional Requirements

- FR-401: Baseline flows F1-F6 SHALL remain behaviorally compatible with state `009-order-management-matcher`.
- FR-402: The browser entrypoint SHALL remain a single origin at `http://localhost:8080`.
- FR-403: Existing API path prefixes (`/account-service`, `/trade-service`, `/reference-data`, etc.) SHALL remain stable in this state.
- FR-404: Pricing and realtime UI semantics inherited from states `008` and `009` SHALL remain intact in Kubernetes runtime:
  - snapshot + stream price bootstrap with server-time ordering for price-aware views,
  - push-based incremental updates for trade/position/order blotters after REST bootstrap.

## Non-Functional Requirements

- NFR-401: Runtime SHALL use Kubernetes (local Kind cluster default for reproducibility, with optional Minikube support for broader developer accessibility).
- NFR-402: The edge entrypoint SHALL use NGINX in-cluster proxying for UI/API/WebSocket traffic.
- NFR-403: Generated manifests SHALL be deterministic and derived from `system/kubernetes-runtime.spec.json`.
- NFR-404: Generated images SHALL be built from generated component source and loaded into the target cluster.
- NFR-405: Runtime topology and architecture SHALL be machine-documented in `system/runtime-topology.md` and `system/architecture.model.json`.
- NFR-406: Observability capabilities inherited from state `009-order-management-matcher` (Prometheus scrape coverage, provisioned Grafana dashboards, and LGTM control-plane services) SHALL remain available through Kubernetes runtime entrypoints.
- NFR-407: NGINX edge routes SHALL forward standard ingress headers (`X-Forwarded-For`, `X-Forwarded-Host`, `X-Forwarded-Proto`, and route-specific `X-Forwarded-Prefix`) to upstream services.

## Success Criteria

- SC-401: `bash pipeline/generate-state.sh 010-kubernetes-runtime` produces Kubernetes artifacts under `generated/code/target-generated/kubernetes-runtime`.
- SC-402: `./scripts/start-state-010-kubernetes-runtime-generated.sh` creates/uses a Kind cluster, applies manifests, and reaches `http://localhost:8080/health`; reruns with `--skip-build` preserve startup behavior without rebuilding images.
- SC-403: `./scripts/test-state-010-kubernetes-runtime.sh` passes core ingress/API/UI smoke checks and inherited observability checks (`/grafana`, `/prometheus`), including `order-matcher` ingress health and orders listing endpoints.
- SC-404: Catalog metadata marks state `009` as implemented with canonical runtime commands.
