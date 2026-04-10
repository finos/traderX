# Generation Hook: 008-pricing-awareness-market-data

- Hook script: `pipeline/generate-state-008-pricing-awareness-market-data.sh`
- Feature pack: `specs/008-pricing-awareness-market-data`

This state follows the patch-set overlay model.

## Patch-Set Inputs

- Parent state id: `008-pricing-awareness-market-data`
- Patch directory: `specs/008-pricing-awareness-market-data/generation/patches/`
- Canonical patch file: `0001-state-overlay.patch`

## Hook Responsibilities

1. Generate parent state output.
2. Apply all ordered patch files from this pack.
3. Regenerate architecture docs from `system/architecture.model.json`.
4. Ensure generated runtime contains `observability-on-pricing` compose assets.
5. Keep compatibility with lineage contracts unless explicitly changed.
6. Produce deterministic output suitable for branch publishing.

Runtime scripts:

- `scripts/start-state-008-pricing-awareness-market-data-generated.sh`
- `scripts/status-state-008-pricing-awareness-market-data-generated.sh`
- `scripts/stop-state-008-pricing-awareness-market-data-generated.sh`
- `scripts/test-state-008-pricing-awareness-market-data.sh`

## Capture / Refresh Patch

Use patch capture workflow after implementing deltas in this state:

```bash
bash pipeline/create-state-patchset.sh 008-pricing-awareness-market-data 008-pricing-awareness-market-data
```
