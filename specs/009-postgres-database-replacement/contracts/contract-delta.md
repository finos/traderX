# Contract Delta: 009-postgres-database-replacement

Parent state: `003-containerized-compose-runtime`

## OpenAPI Changes

- No REST OpenAPI contract changes.

## Event Contract Changes

- No trade-feed Socket.IO event contract changes in this state.

## Compatibility Notes

- UI-visible behavior and endpoint contracts are intentionally preserved.
- Persistence backend contract changes are internal (SQL engine + init process) and do not change REST payload shapes.
- Account sequence semantics are preserved using PostgreSQL `accounts_seq`.
