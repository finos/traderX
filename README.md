# TraderX Generated Code Snapshot

This branch is an auto-published generated-code snapshot for FINOS TraderX.

- State ID: `002-edge-proxy-uncontainerized`
- State Title: `Edge Proxy Uncontainerized`
- Status: `implemented`
- Suggested Version Tag: `generated/002-edge-proxy-uncontainerized/v1`
- Source Branch: `feature/agentic-renovation`
- Source Commit: `12f250c81ff983450ff706f451641567df971bd2`
- Generated At (UTC): `2026-03-29T13:53:59Z`

## State Summary

- Builds on state `001` while keeping uncontainerized process runtime.
- Adds `edge-proxy` as a single browser-facing origin for UI + API + WebSocket traffic.
- Preserves baseline functional behavior with topology-focused NFR deltas.

## State Lineage

- Previous states: `001-baseline-uncontainerized-parity`
- Next states: `003-containerized-compose-runtime`

## Runtime Guidance

Run directly from this generated snapshot branch:

```bash
./scripts/start-state-002-edge-proxy-generated.sh
```

Browser endpoint (via edge proxy): `http://localhost:18080`

Status / stop:

```bash
./scripts/status-state-002-edge-proxy-generated.sh
./scripts/stop-state-002-edge-proxy-generated.sh
```

Detailed clone-first instructions: [RUN_FROM_CLONE.md](./RUN_FROM_CLONE.md)

## Canonical Specs And Docs

Canonical source-of-truth is maintained in the SpecKit authoring branch, not in this code snapshot branch.

- Feature pack: `specs/002-edge-proxy-uncontainerized`
- Generation entrypoint: `bash pipeline/generate-state.sh 002-edge-proxy-uncontainerized`
- Snapshot metadata: [STATE.md](./STATE.md), [state.json](./.traderx-state/state.json)
- Source commit: https://github.com/finos/traderX/commit/12f250c81ff983450ff706f451641567df971bd2
- Feature pack at source commit: https://github.com/finos/traderX/tree/12f250c81ff983450ff706f451641567df971bd2/specs/002-edge-proxy-uncontainerized
- SpecKit docs at source commit: https://github.com/finos/traderX/tree/12f250c81ff983450ff706f451641567df971bd2/docs/spec-kit
