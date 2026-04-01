# Generation Hook: 010-pricing-awareness-market-data

- Hook script: `pipeline/generate-state-010-pricing-awareness-market-data.sh`
- Feature pack: `specs/010-pricing-awareness-market-data`

Patch-set model:

- Parent state: `007-messaging-nats-replacement`
- Patch path: `specs/010-pricing-awareness-market-data/generation/patches/0001-state-overlay.patch`
- Patch target root: `generated/code/target-generated`

Hook flow:

1. Generate parent state `007`.
2. Apply state patch set (pricing component + trade/position/web deltas).
3. Regenerate architecture docs.

Patch refresh command:

```bash
bash pipeline/create-state-patchset.sh 010-pricing-awareness-market-data 007-messaging-nats-replacement
```
