# Feature Specification: Platform Convergence C3

**Feature Branch**: `012-platform-convergence-c3`  
**Created**: 2026-04-06  
**Status**: Implemented  
**Input**: Transition delta from `011-tilt-kubernetes-dev-loop` (dotted-line convergence parent `009-order-management-matcher`)

## User Stories

- As a maintainer, I want an explicit C3 convergence checkpoint that is easy to target for new work.
- As a contributor, I want the publish lineage to stay single-parent while convergence context is still documented.
- As a developer, I want C2 functional capabilities and C3 platform capabilities available together in one recommended state.

## Functional Requirements

- FR-01101: Functional behavior remains compatible with C2 (`009-order-management-matcher`) as carried through state `010`.
- FR-01102: No new external API contracts are introduced solely by this convergence checkpoint.

## Non-Functional Requirements

- NFR-01101: State `011` is marked as convergence level `C3` in `catalog/state-catalog.json`.
- NFR-01102: Publish lineage remains single-parent (`previous=["011-tilt-kubernetes-dev-loop"]`).
- NFR-01103: Dotted-line lineage (`dottedParents=["009-order-management-matcher"]`) is documentation metadata only.
- NFR-01104: Convergence rationale is recorded and maintained in `system/convergence-rationale.md`.
- NFR-01105: As convergence level `C3`, generated state branches MUST include `.github/workflows/build-and-publish.yml` for container image publication.
- NFR-01106: `C3` image publication namespace MUST use `ghcr.io/finos/traderx-c3/<component>` with immutable commit-SHA tags plus `latest`.
- NFR-01107: Generated artifacts MUST include a GHCR run bundle for running this state from published images.

## Success Criteria

- SC-01101: Convergence metadata appears in generated learning docs and visual graphs.
- SC-01102: Convergence policy validation gates pass.
- SC-01103: Generated snapshot metadata and README include convergence neighborhood details.
- SC-01104: Generated branch artifacts include `C3` build/publish workflow and GHCR run-bundle assets.
