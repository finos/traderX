# Generation Hook: 013-order-management-matcher

- Hook script: `pipeline/generate-state-013-order-management-matcher.sh`
- Feature pack: `specs/013-order-management-matcher`

This state follows the patch-set overlay model.

## Patch-Set Inputs

- Parent state id: `012-observability-on-pricing`
- Patch directory: `specs/013-order-management-matcher/generation/patches/`
- Canonical patch file: `0001-state-overlay.patch`

## Hook Responsibilities

1. Generate parent state output.
2. Apply all ordered patch files from this pack.
3. Regenerate architecture docs from `system/architecture.model.json`.
4. Materialize order-management observability assets (metrics wiring, probes, dashboards) defined by this pack.
5. Keep compatibility with lineage contracts unless explicitly changed.
6. Produce deterministic output suitable for branch publishing.

Runtime scripts:

- `scripts/start-state-013-order-management-matcher-generated.sh`
- `scripts/status-state-013-order-management-matcher-generated.sh`
- `scripts/stop-state-013-order-management-matcher-generated.sh`
- `scripts/test-state-013-order-management-matcher.sh`

## Capture / Refresh Patch

Use patch capture workflow after implementing deltas in this state:

```bash
bash pipeline/create-state-patchset.sh 013-order-management-matcher 012-observability-on-pricing
```
