# TraderX Generated Code Snapshot

This branch is an auto-published generated-code snapshot for FINOS TraderX.

- State ID: `003-containerized-compose-runtime`
- State Title: `Containerized Compose Runtime (NGINX Ingress)`
- Status: `implemented`
- Suggested Version Tag: `generated/003-containerized-compose-runtime/v1`
- Source Branch: `feature/agentic-renovation`
- Source Commit: `b50d3b8830bef17bedc5a6f2fb10dc98aeece650`
- Generated At (UTC): `2026-03-29T13:05:01Z`

## State Summary

- Builds on state `002` by moving runtime to Docker Compose.
- Uses NGINX ingress (`ingress` service) as the browser/API/WebSocket entrypoint.
- Preserves baseline functional behavior while changing runtime/ops model.

## State Lineage

- Previous states: `002-edge-proxy-uncontainerized`
- Next states: `none`

## Runtime Guidance

Run directly from this generated snapshot branch:

```bash
./scripts/start-state-003-containerized-generated.sh
```

UI/ingress endpoint: `http://localhost:8080`

Stop:

```bash
./scripts/stop-state-003-containerized-generated.sh
```

Detailed clone-first instructions: [RUN_FROM_CLONE.md](./RUN_FROM_CLONE.md)

## Canonical Specs And Docs

Canonical source-of-truth is maintained in the SpecKit authoring branch, not in this code snapshot branch.

- Feature pack: `specs/003-containerized-compose-runtime`
- Generation entrypoint: `bash pipeline/generate-state.sh 003-containerized-compose-runtime`
- Snapshot metadata: [STATE.md](./STATE.md), [state.json](./.traderx-state/state.json)
- Source commit: https://github.com/finos/traderX/commit/b50d3b8830bef17bedc5a6f2fb10dc98aeece650
- Feature pack at source commit: https://github.com/finos/traderX/tree/b50d3b8830bef17bedc5a6f2fb10dc98aeece650/specs/003-containerized-compose-runtime
- SpecKit docs at source commit: https://github.com/finos/traderX/tree/b50d3b8830bef17bedc5a6f2fb10dc98aeece650/docs/spec-kit
