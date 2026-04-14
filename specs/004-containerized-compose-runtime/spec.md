# Feature Specification: Containerized Compose Runtime

**Feature Branch**: `004-containerized-compose-runtime`  
**Created**: 2026-03-29  
**Status**: Implemented  
**Input**: Transition delta from `002-edge-proxy-uncontainerized`

## User Stories

- As a developer, I want one command to start the full stack in containers.
- As a developer, I want deterministic inter-service networking in container runtime.
- As a platform engineer, I want an industry-standard ingress implementation in this state.
- As a maintainer, I want containerized state generation to remain spec-first and reproducible.
- As a learner, I want state-aware header/About UX preserved in the containerized state.
- As a learner, I want the `Status` page introduced in state `002` to remain available with container-runtime health visibility.

## Functional Requirements

- FR-301: Baseline flows F1-F6 SHALL remain behaviorally compatible in containerized runtime.
- FR-302: State SHALL expose documented runtime entrypoints for UI and APIs in container mode.
- FR-303: Ingress runtime SHALL expose a standalone API explorer at `/api/docs`, backed by state API metadata and service OpenAPI specs.
- FR-304: GUI state-awareness requirements from state `001` (header title with active state id, About page metadata/lineage, API explorer link) SHALL be preserved.
- FR-305: `Status` page requirements from state `002` SHALL be preserved and rendered through ingress for this state.
- FR-306: Status page SHALL report uptime/health for each service participating in this containerized runtime.

## Non-Functional Requirements

- NFR-301: Runtime SHALL be Docker/Docker Compose based for this state.
- NFR-302: Container startup SHALL honor dependency ordering and health readiness checks.
- NFR-303: Container networking and service discovery SHALL be deterministic and documented.
- NFR-304: Generated containerized artifacts SHALL be produced from specs and validated before release tagging.
- NFR-305: Browser ingress in this state SHALL use NGINX reverse-proxy configuration generated from spec artifacts.
- NFR-306: As convergence level `C0`, generated state branches MUST include `.github/workflows/build-and-publish.yml` for container image publication.
- NFR-307: `C0` image publication namespace MUST use `ghcr.io/finos/traderx-c0/<component>` with immutable commit-SHA tags plus `latest`.
- NFR-308: Generated artifacts MUST include a GHCR run bundle for running this state from published images.
- NFR-309: NGINX ingress routes SHALL forward standard ingress headers (`X-Forwarded-For`, `X-Forwarded-Host`, `X-Forwarded-Proto`, and route-specific `X-Forwarded-Prefix`) to upstream services.
- NFR-310: API explorer "Try it out" requests in ingress/containerized states SHALL honor service path prefixes (for example `/order-matcher`, `/people-service`) and MUST NOT fallback to root-relative service paths.
- NFR-311: Runtime/start scripts for this state SHALL detect and report currently generated state id versus expected state id before startup.
- NFR-312: On mismatch, runtime/start scripts SHALL provide explicit guidance for forward-regenerate versus backward clean rebuild decisions.
- NFR-313: Runtime/start scripts SHALL support an explicit opt-in mode to auto-regenerate expected state before startup.

## Success Criteria

- SC-301: Containerized stack starts with one documented command path.
- SC-302: Smoke/conformance checks pass against containerized state.
- SC-303: Generated snapshot tag published with linked validation evidence.
- SC-304: Generated branch artifacts include `C0` build/publish workflow and GHCR run-bundle assets.
- SC-305: After state startup, API explorer is reachable at `http://localhost:8080/api/docs` and interactive requests route through prefixed service paths.
- SC-306: Ingress-routed UI smoke tests verify header title includes `004-containerized-compose-runtime`, About metadata renders expected lineage/source fields, and API explorer link is available.
- SC-307: Ingress-routed UI smoke tests verify `Status` page is reachable and shows per-service uptime/health entries for this state.
- SC-308: Startup script smoke checks verify generated-state detection messaging for both match and mismatch cases, including opt-in auto-regeneration flow.
