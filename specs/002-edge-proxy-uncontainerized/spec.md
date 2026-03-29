# Feature Specification: Edge Proxy Uncontainerized

**Feature Branch**: `002-edge-proxy-uncontainerized`  
**Created**: 2026-03-29  
**Status**: Draft  
**Input**: Transition delta from `001-baseline-uncontainerized-parity`

## User Stories

- As a developer, I want browser traffic to flow through one edge endpoint so local setup is simpler.
- As a developer, I want backend services to keep existing contracts while edge routing is introduced.
- As a maintainer, I want this state to remain generated from specs with full parity checks.

## Functional Requirements

- FR-201: The state SHALL expose a single browser-facing edge endpoint for baseline UI traffic.
- FR-202: The edge SHALL route requests to existing backend services without changing current API contracts.
- FR-203: Existing baseline end-to-end flows F1-F6 SHALL remain behaviorally compatible.

## Non-Functional Requirements

- NFR-201: Browser calls SHALL no longer require direct cross-origin access to every backend service port.
- NFR-202: Runtime SHALL remain uncontainerized in this state.
- NFR-203: State generation SHALL remain deterministic from spec inputs.
- NFR-204: State SHALL pass conformance, smoke, and docs validation before release tagging.

## Success Criteria

- SC-201: UI works end-to-end through the edge endpoint for baseline flows.
- SC-202: No contract drift relative to approved contracts unless explicitly updated in this pack.
- SC-203: Generated snapshot is tagged and linked to validation evidence.
