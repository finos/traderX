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

- `TraderSpec/codebase/scripts/test-database-overlay.sh`
