# PostgreSQL Migration Guidance (State 009)

Parent state: `003-containerized-compose-runtime`

## Intent

Migrate only the runtime database engine from H2 to PostgreSQL while preserving baseline functional behavior and service contracts.

## Migration Steps

1. Generate parent state `003` artifacts.
2. Replace compose database service with PostgreSQL container + init SQL mount.
3. Update datasource properties and drivers for DB-dependent services:
   - `account-service`
   - `position-service`
   - `trade-processor`
4. Preserve business flow behavior and endpoint contracts.
5. Validate with state-specific smoke checks.

## Compatibility Notes

- Baseline API and event contracts remain unchanged.
- H2 web console is intentionally removed from runtime expectations.
- Account ID sequencing is preserved using PostgreSQL sequence `accounts_seq`.
