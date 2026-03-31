# Smoke Tests: 009-postgres-database-replacement

- Primary smoke script: `scripts/test-state-009-postgres-database-replacement.sh`

Required checks for this state:

- Compose services are running with PostgreSQL healthy.
- Baseline PostgreSQL schema and seed data are loaded.
- Ingress health/UI routes are functional.
- Core baseline service smoke checks still pass.
- Realtime account stream behavior still passes through trade-feed path.
