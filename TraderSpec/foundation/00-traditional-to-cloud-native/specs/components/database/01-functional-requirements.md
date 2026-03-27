# Database Functional Requirements

## Scope

Define baseline functional behavior for the next pure-generated cutover target: `database`.

## Functional Requirements

- FR-DB-001: Service shall start an H2 database server exposing TCP on `18082`, PG compatibility on `18083`, and web console on `18084`.
- FR-DB-002: On startup, service shall initialize schema using `initialSchema.sql`.
- FR-DB-003: Schema shall include `Accounts`, `AccountUsers`, `Positions`, and `Trades` with baseline keys/constraints.
- FR-DB-004: Baseline sample data from `initialSchema.sql` shall be loaded on startup.
- FR-DB-005: Service shall provide data compatibility required by account-service, position-service, and trade-processor.
- FR-DB-006: Account ID sequence `ACCOUNTS_SEQ` shall exist with baseline increment behavior.

## Out Of Scope

- No DB engine replacement in this phase.
- No schema redesign in this phase.
- No data migration to external persistent database in this phase.
