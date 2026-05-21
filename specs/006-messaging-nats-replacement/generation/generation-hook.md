# Generation Hook: 006-messaging-nats-replacement

- Hook script: `pipeline/generate-state-006-messaging-nats-replacement.sh`
- Feature pack: `specs/006-messaging-nats-replacement`

Patch-set model:

- Parent state: `005-postgres-database-replacement`
- Patch path: `specs/006-messaging-nats-replacement/generation/patches/0001-state-overlay.patch`
- Patch target root: `generated/code/target-generated`

Hook flow:

1. Generate parent state `005`.
2. Apply state patch set (trade-feed replacement with NATS + service/frontend deltas).
3. Regenerate architecture docs.

Patch refresh command:

```bash
bash pipeline/create-state-patchset.sh 006-messaging-nats-replacement 005-postgres-database-replacement
```
