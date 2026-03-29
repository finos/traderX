# TraderX Generated Code Snapshot

This branch is an auto-published generated-code snapshot for FINOS TraderX.

- State ID: `003-containerized-compose-runtime`
- State Title: `Containerized Compose Runtime (NGINX Ingress)`
- Status: `implemented`
- Suggested Version Tag: `generated/003-containerized-compose-runtime/v1`
- Source Branch: `feature/agentic-renovation`
- Source Commit: `486f97f130817bd3180d1833bff3ff16a608f566`
- Generated At (UTC): `2026-03-29T12:39:59Z`

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
docker compose -f containerized-compose/docker-compose.yml up -d --build
```

UI/ingress endpoint: `http://localhost:8080`

Stop:

```bash
docker compose -f containerized-compose/docker-compose.yml down --remove-orphans
```

## Canonical Specs And Docs

Canonical source-of-truth is maintained in the SpecKit authoring branch, not in this code snapshot branch.

- Feature pack: `specs/003-containerized-compose-runtime`
- Generation entrypoint: `bash pipeline/generate-state.sh 003-containerized-compose-runtime`
- Snapshot metadata: [STATE.md](./STATE.md), [state.json](./.traderx-state/state.json)
- Source commit: https://github.com/finos/traderX/commit/486f97f130817bd3180d1833bff3ff16a608f566
- Feature pack at source commit: https://github.com/finos/traderX/tree/486f97f130817bd3180d1833bff3ff16a608f566/specs/003-containerized-compose-runtime
- SpecKit docs at source commit: https://github.com/finos/traderX/tree/486f97f130817bd3180d1833bff3ff16a608f566/docs/spec-kit
