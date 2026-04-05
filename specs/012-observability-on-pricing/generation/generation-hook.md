# Generation Hook: 012-observability-on-pricing

- Hook script: `pipeline/generate-state-012-observability-on-pricing.sh`
- Feature pack: `specs/012-observability-on-pricing`

This state follows the patch-set overlay model.

## Patch-Set Inputs

- Parent state id: `010-pricing-awareness-market-data`
- Patch directory: `specs/012-observability-on-pricing/generation/patches/`
- Canonical patch file: `0001-state-overlay.patch`

## Hook Responsibilities

1. Generate parent state output.
2. Apply all ordered patch files from this pack.
3. Regenerate architecture docs from `system/architecture.model.json`.
4. Ensure generated runtime contains `observability-on-pricing` compose assets.
5. Keep compatibility with lineage contracts unless explicitly changed.
6. Produce deterministic output suitable for branch publishing.

Runtime scripts:

- `scripts/start-state-012-observability-on-pricing-generated.sh`
- `scripts/status-state-012-observability-on-pricing-generated.sh`
- `scripts/stop-state-012-observability-on-pricing-generated.sh`
- `scripts/test-state-012-observability-on-pricing.sh`

## Capture / Refresh Patch

Use patch capture workflow after implementing deltas in this state:

```bash
bash pipeline/create-state-patchset.sh 012-observability-on-pricing 010-pricing-awareness-market-data
```
