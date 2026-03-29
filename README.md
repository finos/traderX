# TraderX Generated Code Snapshot

This branch is an auto-published generated-code snapshot for FINOS TraderX.

- State ID: `001-baseline-uncontainerized-parity`
- State Title: `Simple App - Base Uncontainerized App`
- Status: `released`
- Suggested Version Tag: `generated/001-baseline-uncontainerized-parity/v1`
- Source Branch: `feature/agentic-renovation`
- Source Commit: `12f250c81ff983450ff706f451641567df971bd2`
- Generated At (UTC): `2026-03-29T13:53:43Z`

## State Summary

- Base case for TraderX generated code.
- Runtime model: uncontainerized local processes in deterministic startup order.
- Browser directly calls multiple service ports (cross-origin CORS behavior is part of this state).

## State Lineage

- Previous states: `none`
- Next states: `002-edge-proxy-uncontainerized`

## Runtime Guidance

Run directly from this generated snapshot branch:

```bash
./scripts/start-base-uncontainerized-generated.sh
```

UI endpoint: `http://localhost:18093`

Status / stop:

```bash
./scripts/status-base-uncontainerized-generated.sh
./scripts/stop-base-uncontainerized-generated.sh
```

Detailed clone-first instructions: [RUN_FROM_CLONE.md](./RUN_FROM_CLONE.md)

## Canonical Specs And Docs

Canonical source-of-truth is maintained in the SpecKit authoring branch, not in this code snapshot branch.

- Feature pack: `specs/001-baseline-uncontainerized-parity`
- Generation entrypoint: `bash pipeline/generate-from-spec.sh`
- Snapshot metadata: [STATE.md](./STATE.md), [state.json](./.traderx-state/state.json)
- Source commit: https://github.com/finos/traderX/commit/12f250c81ff983450ff706f451641567df971bd2
- Feature pack at source commit: https://github.com/finos/traderX/tree/12f250c81ff983450ff706f451641567df971bd2/specs/001-baseline-uncontainerized-parity
- SpecKit docs at source commit: https://github.com/finos/traderX/tree/12f250c81ff983450ff706f451641567df971bd2/docs/spec-kit
