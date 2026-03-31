# Functional Delta: 009-postgres-database-replacement

Parent state: `003-containerized-compose-runtime`

## Added

- PostgreSQL runtime initialization pack (`postgres-init/initialSchema.sql`) for deterministic baseline schema and seed data.
- Postgres-specific smoke checks (readiness + baseline data presence).

## Changed

- Runtime database engine changes from H2 server process to PostgreSQL container.
- Service datasource wiring for:
  - `account-service`
  - `position-service`
  - `trade-processor`
- Account sequence ID generation query changes to PostgreSQL sequence syntax.

## Removed

- H2 web-console behavior from the runtime path (`/database` ingress route is no longer a supported interactive console flow in this state).

## Flow Impact

- `F1` load accounts on UI load: unchanged behavior, now backed by PostgreSQL reads.
- `F2` bootstrap blotters: unchanged behavior, now backed by PostgreSQL reads.
- `F3` account administration: unchanged behavior, account creation uses PostgreSQL sequence.
- `F4` realtime blotter updates: unchanged behavior, writes/reads occur against PostgreSQL.
