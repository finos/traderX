# Spec Kit Component: database

## Responsibilities

- Host H2 database runtime for baseline services.
- Provide seeded account, trade, position, and account-user data.
- Expose TCP/PG/Web console ports for service access and local inspection.

## Covered Flows

- `STARTUP`
- `F4` (persistence for trade processing)
- `F5` and `F6` (account and account-user persistence)

## Requirement Coverage

- `SYS-FR-001`, `SYS-FR-007`
- `SYS-NFR-002`, `SYS-NFR-004`

## Verification

- `scripts/test-database-overlay.sh`

## Connection retirement and existing databases (#461)

The H2 schema uses CASE for Trades.Side/State and OrderBook.Side/Status checks.
Do not regenerate literal IN-list checks: H2 2.4.240 can retain the closed schema
session's comparator. Invalid values must still fail and NULL remains allowed.
`templates/database-specfirst/src/test/java/SchemaConnectionRetirementTest.java`
executes the canonical schema and validates all allowed values after creator closure.
Existing persistent databases require a backed-up constraint migration; regeneration
alone does not alter their constraints. Never run the destructive initial schema to
repair an existing database. See `docs/operations/h2-booking-constraint-migration.md`.
