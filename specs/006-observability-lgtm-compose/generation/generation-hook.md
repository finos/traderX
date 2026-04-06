# Generation Hook: 006-observability-lgtm-compose

- Hook script: `pipeline/generate-state-006-observability-lgtm-compose.sh`
- Feature pack: `specs/006-observability-lgtm-compose`

This state follows the patch-set overlay model.

## Patch-Set Inputs

- Parent state id: `005-messaging-nats-replacement`
- Patch directory: `specs/006-observability-lgtm-compose/generation/patches/`
- Canonical patch file: `0001-state-overlay.patch`

## Hook Responsibilities

1. Generate parent state output.
2. Apply all ordered patch files from this pack.
3. Regenerate architecture docs from `system/architecture.model.json`.
4. Ensure generated runtime contains `observability-lgtm-compose` compose assets.
5. Keep compatibility with lineage contracts unless explicitly changed.
6. Produce deterministic output suitable for branch publishing.

Runtime scripts:

- `scripts/start-state-006-observability-lgtm-compose-generated.sh`
- `scripts/status-state-006-observability-lgtm-compose-generated.sh`
- `scripts/stop-state-006-observability-lgtm-compose-generated.sh`
- `scripts/test-state-006-observability-lgtm-compose.sh`

## Capture / Refresh Patch

Use patch capture workflow after implementing deltas in this state:

```bash
bash pipeline/create-state-patchset.sh 006-observability-lgtm-compose 005-messaging-nats-replacement
```
