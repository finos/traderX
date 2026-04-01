# Generation Hook: 009-postgres-database-replacement

- Hook script: `pipeline/generate-state-009-postgres-database-replacement.sh`
- Feature pack: `specs/009-postgres-database-replacement`

Patch-set model:

- Parent state: `003-containerized-compose-runtime`
- Patch path: `specs/009-postgres-database-replacement/generation/patches/0001-state-overlay.patch`
- Patch target root: `generated/code/target-generated`

Hook flow:

1. Generate parent state `003`.
2. Apply state patch set (PostgreSQL runtime + service DB config deltas).
3. Regenerate architecture docs.

Patch refresh command:

```bash
bash pipeline/create-state-patchset.sh 009-postgres-database-replacement 003-containerized-compose-runtime
```
