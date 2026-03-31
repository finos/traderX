# Non-Functional Delta: 009-postgres-database-replacement

Parent state: `003-containerized-compose-runtime`

## Runtime / Operations

- Runtime remains Docker Compose + NGINX ingress from state `003`.
- Database service switches to `postgres:16-alpine` with deterministic init SQL mounted at startup.
- DB-dependent services use `depends_on` health sequencing against PostgreSQL readiness.

## Security / Compliance

- No auth/TLS model changes are introduced in this state.
- Default local development credentials are intentionally simple and state-scoped.

## Performance / Scalability

- PostgreSQL provides more production-like query/transaction behavior than H2 while preserving local simplicity.
- No horizontal scaling changes are introduced in this state.

## Reliability / Observability

- Startup checks include PostgreSQL readiness to reduce race-condition failures.
- Smoke checks validate baseline data load and service compatibility against PostgreSQL.
