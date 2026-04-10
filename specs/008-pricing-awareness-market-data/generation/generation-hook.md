# Generation Hook: 008-pricing-awareness-market-data

- Hook script: `pipeline/generate-state-008-pricing-awareness-market-data.sh`
- Feature pack: `specs/008-pricing-awareness-market-data`

Patch-set model:

- Parent state: `007-observability-lgtm-compose`
- Patch path: `specs/008-pricing-awareness-market-data/generation/patches/0001-state-overlay.patch`
- Patch target root: `generated/code/target-generated`

Hook flow:

1. Generate parent state `006`.
2. Apply state patch set (pricing component + trade/position/web deltas).
3. Regenerate architecture docs.

Patch refresh command:

```bash
bash pipeline/create-state-patchset.sh 008-pricing-awareness-market-data 007-observability-lgtm-compose
```
