# System Design

State: `009-postgres-database-replacement`

## Design Intent

State 009 replaces H2 database runtime with PostgreSQL while preserving state 003 containerized ingress topology and baseline flows.

## Runtime Topology / Flow (Spec Extract)

# Runtime Topology: 009-postgres-database-replacement

Parent state: `003-containerized-compose-runtime`

State `009` preserves the compose + ingress topology from state `003` and replaces only the database runtime implementation.

## Entrypoints

- Browser/UI via NGINX ingress: `http://localhost:8080`
- Reference-data direct (diagnostic): `http://localhost:18085`
- PostgreSQL TCP (diagnostic/local tooling): `localhost:18083 -> container:5432`

## Components

- `database` -> PostgreSQL container (`postgres:16-alpine`)
- `reference-data` -> unchanged from state `003`
- `trade-feed` -> unchanged from state `003`
- `people-service` -> unchanged from state `003`
- `account-service` -> datasource updated for PostgreSQL
- `position-service` -> datasource updated for PostgreSQL
- `trade-processor` -> datasource + JPA dialect updated for PostgreSQL
- `trade-service` -> unchanged from state `003`
- `web-front-end-angular` -> unchanged from state `003`
- `ingress` -> unchanged from state `003` (database route retained for topology compatibility but no H2 console)

## Networking

- Container-to-container DB connectivity uses `database:5432`.
- Host-to-container DB diagnostics use `localhost:18083`.
- Service cross-calls and ingress path routing are unchanged from state `003`.

## Startup / Health Order

1. `database` starts and passes `pg_isready` health check.
2. DB-dependent services (`account-service`, `position-service`, `trade-processor`) start.
3. Remaining services and `ingress` start.
4. Smoke checks verify baseline API/UI and realtime behaviors remain intact.
