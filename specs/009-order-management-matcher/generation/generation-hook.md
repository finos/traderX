# Generation Hook: 009-order-management-matcher

- Hook script: `pipeline/generate-state-009-order-management-matcher.sh`
- Feature pack: `specs/009-order-management-matcher`

This state follows the patch-set overlay model.

## Patch-Set Inputs

- Parent state id: `008-pricing-awareness-market-data`
- Patch directory: `specs/009-order-management-matcher/generation/patches/`
- Canonical patch file: `0001-state-overlay.patch`

## Hook Responsibilities

1. Generate parent state output.
2. Apply all ordered patch files from this pack.
3. Regenerate architecture docs from `system/architecture.model.json`.
4. Materialize order-management observability assets (metrics wiring, probes, dashboards) defined by this pack.
5. Keep compatibility with lineage contracts unless explicitly changed.
6. Produce deterministic output suitable for branch publishing.

Runtime scripts:

- `scripts/start-state-009-order-management-matcher-generated.sh`
- `scripts/status-state-009-order-management-matcher-generated.sh`
- `scripts/stop-state-009-order-management-matcher-generated.sh`
- `scripts/test-state-009-order-management-matcher.sh`

## Capture / Refresh Patch

Use patch capture workflow after implementing deltas in this state:

```bash
bash pipeline/create-state-patchset.sh 009-order-management-matcher 008-pricing-awareness-market-data
```
