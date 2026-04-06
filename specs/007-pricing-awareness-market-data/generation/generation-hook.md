# Generation Hook: 007-pricing-awareness-market-data

- Hook script: `pipeline/generate-state-007-pricing-awareness-market-data.sh`
- Feature pack: `specs/007-pricing-awareness-market-data`

Patch-set model:

- Parent state: `006-observability-lgtm-compose`
- Patch path: `specs/007-pricing-awareness-market-data/generation/patches/0001-state-overlay.patch`
- Patch target root: `generated/code/target-generated`

Hook flow:

1. Generate parent state `006`.
2. Apply state patch set (pricing component + trade/position/web deltas).
3. Regenerate architecture docs.

Patch refresh command:

```bash
bash pipeline/create-state-patchset.sh 007-pricing-awareness-market-data 006-observability-lgtm-compose
```
