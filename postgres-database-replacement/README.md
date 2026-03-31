# State 009 PostgreSQL Database Replacement

Generated from:

- `specs/009-postgres-database-replacement/**`
- parent state `003-containerized-compose-runtime`

State intent:

- replace H2 runtime database with PostgreSQL while preserving baseline behavior,
- keep edge ingress and Docker Compose runtime model from state 003,
- keep existing REST and messaging contracts stable for baseline flows.

Artifacts:

- Compose runtime: `docker-compose.yml`
- Postgres bootstrap schema/data: `postgres-init/initialSchema.sql`
- Spec references: `spec-source/*`

Run:

```bash
./scripts/start-state-009-postgres-database-replacement-generated.sh
```

Smoke tests:

```bash
./scripts/test-state-009-postgres-database-replacement.sh
```
