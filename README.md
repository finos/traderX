# TraderX Generated Code Snapshot

This branch is an auto-published generated-code snapshot for FINOS TraderX.

- State ID: `002-edge-proxy-uncontainerized`
- State Title: `Edge Proxy Uncontainerized`
- Status: `implemented`
- Suggested Version Tag: `generated/002-edge-proxy-uncontainerized/v1`
- Source Branch: `feature/agentic-renovation`
- Source Commit: `486f97f130817bd3180d1833bff3ff16a608f566`
- Generated At (UTC): `2026-03-29T12:40:22Z`

## State Summary

- Builds on state `001` while keeping uncontainerized process runtime.
- Adds `edge-proxy` as a single browser-facing origin for UI + API + WebSocket traffic.
- Preserves baseline functional behavior with topology-focused NFR deltas.

## State Lineage

- Previous states: `001-baseline-uncontainerized-parity`
- Next states: `003-containerized-compose-runtime`

## Runtime Guidance

This generated branch is a code snapshot and does not include the full SpecKit orchestration workspace.

For reproducible startup/verification, use the canonical source branch at commit `486f97f130817bd3180d1833bff3ff16a608f566`:

```bash
git checkout 486f97f130817bd3180d1833bff3ff16a608f566
bash pipeline/generate-state.sh 002-edge-proxy-uncontainerized
./scripts/start-state-002-edge-proxy-generated.sh
```

## Canonical Specs And Docs

Canonical source-of-truth is maintained in the SpecKit authoring branch, not in this code snapshot branch.

- Feature pack: `specs/002-edge-proxy-uncontainerized`
- Generation entrypoint: `bash pipeline/generate-state.sh 002-edge-proxy-uncontainerized`
- Snapshot metadata: [STATE.md](./STATE.md), [state.json](./.traderx-state/state.json)
- Source commit: https://github.com/finos/traderX/commit/486f97f130817bd3180d1833bff3ff16a608f566
- Feature pack at source commit: https://github.com/finos/traderX/tree/486f97f130817bd3180d1833bff3ff16a608f566/specs/002-edge-proxy-uncontainerized
- SpecKit docs at source commit: https://github.com/finos/traderX/tree/486f97f130817bd3180d1833bff3ff16a608f566/docs/spec-kit
