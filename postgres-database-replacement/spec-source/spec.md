# Feature Specification: PostgreSQL Database Replacement

**Feature Branch**: `009-postgres-database-replacement`  
**Created**: 2026-03-31  
**Status**: Implemented  
**Input**: Transition delta from `003-containerized-compose-runtime`

## User Stories

- As a maintainer, I want the baseline runtime to use a real PostgreSQL database without changing user-visible baseline behavior.
- As a contributor, I want this architecture branch to stay close to state `003` except for the database engine replacement.
- As a developer, I want generated code and smoke tests to prove that account/position/trade flows still work end-to-end.

## Functional Requirements

- FR-901: State runtime SHALL replace H2 database runtime with a PostgreSQL container initialized from deterministic schema/data scripts.
- FR-902: Account, position, and trade-processor services SHALL use PostgreSQL datasource configuration in this state.
- FR-903: Baseline flows `F1`, `F2`, `F3`, and `F4` from state `001` SHALL remain behaviorally compatible.
- FR-904: Account identifier generation semantics SHALL remain compatible via sequence-backed ID generation.
- FR-905: State SHALL keep Docker Compose + NGINX ingress model inherited from state `003`.

## Non-Functional Requirements

- NFR-901: Local runtime SHALL remain single-command containerized startup for contributors.
- NFR-902: Database runtime SHALL use an official lightweight PostgreSQL container image.
- NFR-903: Runtime SHALL include readiness/health expectations sufficient to avoid race conditions during startup.
- NFR-904: State generation SHALL be deterministic and reproducible from spec-driven assets.
- NFR-905: State SHALL preserve lineage compareability against state `003`.

## Success Criteria

- SC-901: `pipeline/generate-state-009-postgres-database-replacement.sh` generates a runnable PostgreSQL-based runtime pack.
- SC-902: `scripts/start-state-009-postgres-database-replacement-generated.sh` starts runtime successfully.
- SC-903: `scripts/test-state-009-postgres-database-replacement.sh` passes core smoke checks.
- SC-904: State catalog points to `code/generated-state-009-postgres-database-replacement`.
- SC-905: ADR for database engine choice is published and linked from state artifacts.
