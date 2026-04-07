# Upstream Sync Runbook

This runbook updates the upstream TraderX pin and revalidates corporate overlays.

## Steps

1. Update submodule pin.
2. Regenerate sanctioned states.
3. Apply corporate transforms.
4. Run validation.
5. Promote the pin only when all checks pass.

## Commands

```bash
./scripts/sync-upstream.sh feature/agentic-renovation
./scripts/demo-generate-corp-overlay.sh 003-containerized-compose-runtime
./scripts/render-internal-learning-graph.sh
```

## Validation Gate Examples

- verify no blocked public image references in generated artifacts
- verify managed Postgres endpoint overlay exists for corp states
- verify internal docs banner is present in internal portal config
