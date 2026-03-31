# State 009 Fidelity Profile

This profile captures the required technical shape for state `009-postgres-database-replacement`.

## Runtime Stack Deltas From State 003

| Concern | State 003 | State 009 |
| --- | --- | --- |
| Database runtime | H2 service process + H2 web console | PostgreSQL container (`postgres:16-alpine`) |
| DB access protocol | H2 TCP / PG emulation | Native PostgreSQL (5432) |
| DB init path | H2 RunScript | PostgreSQL init SQL via `/docker-entrypoint-initdb.d` |
| Ingress model | NGINX | NGINX (unchanged) |
| Runtime model | Docker Compose | Docker Compose (unchanged) |

## PostgreSQL Baseline Constraints

- PostgreSQL image remains lightweight and local-friendly.
- State uses deterministic schema and seed data from a committed init script.
- Account sequence semantics remain compatible (`accounts_seq`).
- DB-dependent service startup is gated on PostgreSQL readiness.

## Closeness Policy

State `009` is architecture-close to `003` with one intentional replacement axis: database runtime engine.

Changes expected:

- replacement of H2 runtime with PostgreSQL container,
- datasource and driver updates in DB-dependent services,
- no intentional REST/event contract drift.
