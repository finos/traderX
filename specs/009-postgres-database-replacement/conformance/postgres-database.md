# postgres-database Conformance Pack

## User Stories

- services persist and query baseline data against PostgreSQL,
- baseline API and realtime flows continue to work after DB engine replacement.

## Functional Requirements

- `FR-901`
- `FR-902`
- `FR-903`
- `FR-904`

## Non-Functional Requirements

- `NFR-901`
- `NFR-902`
- `NFR-903`
- `NFR-904`

## Acceptance Criteria

- PostgreSQL container becomes healthy and reachable in compose runtime.
- Baseline schema + seed data are present after startup.
- Account/position/trade-processor service flows pass baseline smoke checks.
- Ingress and UI baseline checks remain functional.

## Verification References

- `scripts/start-state-009-postgres-database-replacement-generated.sh`
- `scripts/test-state-009-postgres-database-replacement.sh`
