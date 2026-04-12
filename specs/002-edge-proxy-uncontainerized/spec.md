# Feature Specification: Edge Proxy Uncontainerized

**Feature Branch**: `002-edge-proxy-uncontainerized`  
**Created**: 2026-03-29  
**Status**: Implemented (pending release tag)  
**Input**: Transition delta from `001-baseline-uncontainerized-parity`

## User Stories

- As a developer, I want browser traffic to flow through one edge endpoint so local setup is simpler.
- As a developer, I want backend services to keep existing contracts while edge routing is introduced.
- As a maintainer, I want this state to remain generated from specs with full parity checks.

## Functional Requirements

- FR-201: The state SHALL expose a single browser-facing edge endpoint for baseline UI traffic.
- FR-202: The edge SHALL route requests to existing backend services without changing current API contracts.
- FR-203: Existing baseline end-to-end flows F1-F6 SHALL remain behaviorally compatible.
- FR-204: The edge endpoint SHALL expose a standalone API explorer at `/api/docs`, backed by state API metadata and service OpenAPI specs.

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

## Success Criteria

- SC-201: UI works end-to-end through the edge endpoint for baseline flows.
- SC-202: No contract drift relative to approved contracts unless explicitly updated in this pack.
- SC-203: Generated snapshot is tagged and linked to validation evidence.
- SC-204: Generated snapshots from this state lineage contain required CI workflow files and scanner suppression files with component-complete coverage.
- SC-205: Generated-state publish fails prior to commit/push when compile preflight fails for any generated module in scope.
- SC-206: After state startup, API explorer is reachable at `http://localhost:18080/api/docs` and interactive requests route through prefixed service paths.

## Generation + Runtime Entry Points

- generation: `bash pipeline/generate-state.sh 002-edge-proxy-uncontainerized`
- runtime: `./scripts/start-state-002-edge-proxy-generated.sh`
- smoke test: `./scripts/test-state-002-edge-proxy.sh`
