# Feature Specification: Edge Proxy Uncontainerized

**Feature Branch**: `002-edge-proxy-uncontainerized`  
**Created**: 2026-03-29  
**Status**: Implemented (pending release tag)  
**Input**: Transition delta from `001-baseline-uncontainerized-parity`

## User Stories

- As a developer, I want browser traffic to flow through one edge endpoint so local setup is simpler.
- As a developer, I want backend services to keep existing contracts while edge routing is introduced.
- As a maintainer, I want this state to remain generated from specs with full parity checks.
- As a learner, I want state-aware header/About UX carried from state `001` and visible through the edge endpoint.
- As a learner, I want a `Status` page that shows service uptime/health through the edge runtime.

## Functional Requirements

- FR-201: The state SHALL expose a single browser-facing edge endpoint for baseline UI traffic.
- FR-202: The edge SHALL route requests to existing backend services without changing current API contracts.
- FR-203: Existing baseline end-to-end flows F1-F6 SHALL remain behaviorally compatible.
- FR-204: The edge endpoint SHALL expose a standalone API explorer at `/api/docs`, backed by state API metadata and service OpenAPI specs.
- FR-205: GUI state-awareness requirements from state `001` (header title with state id + About page metadata/linkage/API explorer link) SHALL be preserved in this state.
- FR-206: GUI top navigation SHALL include a `Status` tab/link in this state and later states in this lineage unless explicitly superseded.
- FR-207: The `Status` page SHALL render uptime/health status for each runtime service participating in this state.
- FR-208: Status-page service status data SHALL be obtained through edge-accessible health/status sources so the page works from the single edge endpoint.

## Non-Functional Requirements

- NFR-201: Browser calls SHALL no longer require direct cross-origin access to every backend service port.
- NFR-202: Runtime SHALL remain uncontainerized in this state.
- NFR-203: State generation SHALL remain deterministic from spec inputs.
- NFR-204: State SHALL pass conformance, smoke, and docs validation before release tagging.
- NFR-205: Generated state branches from `002+` SHALL include dependency security scanning and Node.js license scanning workflows appropriate to the components present in the generated codebase.
- NFR-206: CVE suppression files used by scanning workflows (`.github/*-cve-ignore-list.xml`) SHALL be present in generated branches and updated when state dependency sets change.
- NFR-207: CI workflow component coverage SHALL be derived from generated state component inventory, and SHALL remain complete for all applicable language/runtime components.
- NFR-208: States `003+` SHALL inherit this generated-branch CI baseline unless a later state explicitly replaces it.
- NFR-209: Every generated Node.js project (`package.json`) SHALL declare `"license": "Apache-2.0"`; new Node services introduced in later states MUST inherit this default unless an explicit state requirement overrides it.
- NFR-210: The edge proxy implementation SHALL forward standard ingress headers (`X-Forwarded-For`, `X-Forwarded-Host`, `X-Forwarded-Proto`, and `X-Forwarded-Prefix` for prefixed routes) to upstream services.
- NFR-211: Generated-state publish flows SHALL require successful compile preflight for all generated modules declared in state metadata (Node.js, Gradle, .NET where present) before commit/push.
- NFR-212: API explorer "Try it out" requests in edge-proxy states SHALL honor service path prefixes (for example `/order-matcher`, `/people-service`) and MUST NOT fallback to root-relative service paths.
- NFR-213: Runtime/start scripts for this state SHALL detect and report currently generated state id versus expected state id before startup.
- NFR-214: On state mismatch, runtime/start scripts SHALL provide explicit guidance for forward-regeneration versus backward clean rebuild decisions.
- NFR-215: Runtime/start scripts SHALL support an explicit opt-in mode to auto-regenerate expected state before startup.
- NFR-216: Generated-state snapshot pruning and generated CI module discovery SHALL be state-scoped; components not in the active state's runtime inventory (for example legacy Node edge-proxy in `004+` states) MUST be excluded unless explicitly reintroduced by a later approved state spec.

## Success Criteria

- SC-201: UI works end-to-end through the edge endpoint for baseline flows.
- SC-202: No contract drift relative to approved contracts unless explicitly updated in this pack.
- SC-203: Generated snapshot is tagged and linked to validation evidence.
- SC-204: Generated snapshots from this state lineage contain required CI workflow files and scanner suppression files with component-complete coverage.
- SC-205: Generated-state publish fails prior to commit/push when compile preflight fails for any generated module in scope.
- SC-206: After state startup, API explorer is reachable at `http://localhost:18080/api/docs` and interactive requests route through prefixed service paths.
- SC-207: Edge-routed UI smoke tests verify header title includes `002-edge-proxy-uncontainerized`, `About` page metadata renders expected lineage/source fields, and API explorer link is available.
- SC-208: Edge-routed UI smoke tests verify `Status` page is reachable and shows per-service uptime/health entries for this state.
- SC-209: Startup script smoke checks verify generated-state detection messaging for both match and mismatch cases, including opt-in auto-regeneration flow.
- SC-210: Publishing snapshots and generated CI metadata for states `004+` excludes the Node `edge-proxy` module unless a later state spec explicitly restores it.

## Generation + Runtime Entry Points

- generation: `bash pipeline/generate-state.sh 002-edge-proxy-uncontainerized`
- runtime (first run/build): `./scripts/start-state-002-edge-proxy-generated.sh --build-only`
- runtime (start after build): `./scripts/start-state-002-edge-proxy-generated.sh`
- smoke test: `./scripts/test-state-002-edge-proxy.sh`
