# Feature Pack 009: PostgreSQL Database Replacement

Status: Implemented
Track: `architecture`
Previous state: `003-containerized-compose-runtime`

This pack defines an architecture-track branch from `003-containerized-compose-runtime` that replaces the runtime database engine from H2 to PostgreSQL while preserving baseline functional behavior.

Primary intent:

- replace H2 with PostgreSQL in Docker Compose runtime,
- keep baseline REST/event contracts stable,
- keep startup and smoke validation deterministic,
- keep generation fully spec-first and reproducible.

Core artifacts:

- `spec.md`
- `requirements/functional-delta.md`
- `requirements/nonfunctional-delta.md`
- `contracts/contract-delta.md`
- `system/architecture.model.json`
- `system/runtime-topology.md`
- `generation/generation-hook.md`
- `tests/smoke/README.md`

Additional artifacts:

- `components/postgres-database.md`
- `conformance/postgres-database.md`
- `system/docker-compose.postgres.snippet.yaml`
- `system/postgres-migration-guidance.md`
- `fidelity-profile.md`

Decision record:

- ADR: [`docs/adr/006-state-009-use-postgres-for-database-replacement.md`](/docs/adr/006-state-009-use-postgres-for-database-replacement)
