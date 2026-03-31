# Generation Hook: 009-postgres-database-replacement

- Hook script: `pipeline/generate-state-009-postgres-database-replacement.sh`
- Feature pack: `specs/009-postgres-database-replacement`

Implemented responsibilities:

1. Generate or transform code artifacts for this state.
2. Apply PostgreSQL overlays to DB-dependent services.
3. Generate PostgreSQL compose runtime assets and init script.
4. Keep compatibility with state lineage contracts unless explicitly changed.
5. Produce deterministic output suitable for branch publishing.
