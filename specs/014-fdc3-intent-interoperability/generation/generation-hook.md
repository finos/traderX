# Generation Hook: 014-fdc3-intent-interoperability

- Hook script: `pipeline/generate-state-014-fdc3-intent-interoperability.sh`
- Render script: `pipeline/render-state-014-fdc3-intent-interoperability.sh`
- Feature pack: `specs/014-fdc3-intent-interoperability`

This state follows the render overlay model (generated artifacts produced from state-local templates/scripts on top of parent state output).

## Render Inputs

- Parent state id: `012-platform-convergence-c3`
- Upstream runtime source: `generated/code/target-generated/tilt-kubernetes-dev-loop`
- State artifact target: `generated/code/target-generated/fdc3-intent-interoperability`

## Hook Responsibilities

1. Generate parent state `012-platform-convergence-c3` into target-generated workspace.
2. Render state-local Sail sidecar artifacts that introduce:
   - Sail sidecar compose and bootstrap scripts
   - Sail pin manifest for deterministic upstream checkout
   - Sail app overlays (TraderX intent launcher + TradingView + Polygon + default client-state seed)
   - TraderX app-directory seed overlay
   - State-local runbook/readme metadata
3. Apply state-local frontend override sources for FDC3 behavior into generated web-frontend output.
4. Regenerate architecture docs from `system/architecture.model.json`.
5. Keep inherited backend contracts stable unless explicitly changed in this pack.
6. Emit deterministic output suitable for generated snapshot publishing.
