# TraderX Generated Code Snapshot

This branch is an auto-published generated-code snapshot for FINOS TraderX.

- State ID: `001-baseline-uncontainerized-parity`
- State Title: `Simple App - Base Uncontainerized App`
- Status: `released`
- Suggested Version Tag: `generated/001-baseline-uncontainerized-parity/v1`
- Source Branch: `feature/agentic-renovation`
- Source Commit: `7d6bc07efdfae09f19840f89a0270bfd0911467e`
- Generated At (UTC): `2026-03-29T12:21:56Z`

## State Summary

- Base case for TraderX generated code.
- Runtime model: uncontainerized local processes in deterministic startup order.
- Browser directly calls multiple service ports (cross-origin CORS behavior is part of this state).

## State Lineage

- Previous states: `none`
- Next states: `002-edge-proxy-uncontainerized`

## Runtime Guidance

This generated branch is a code snapshot and does not include the full SpecKit orchestration workspace.

For reproducible startup/verification, use the canonical source branch at commit `7d6bc07efdfae09f19840f89a0270bfd0911467e`:

```bash
git checkout 7d6bc07efdfae09f19840f89a0270bfd0911467e
bash pipeline/generate-state.sh 001-baseline-uncontainerized-parity
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./scripts/start-base-uncontainerized-generated.sh
```

## Canonical Specs And Docs

Canonical source-of-truth is maintained in the SpecKit authoring branch, not in this code snapshot branch.

- Feature pack: `specs/001-baseline-uncontainerized-parity`
- Generation entrypoint: `bash pipeline/generate-from-spec.sh`
- Snapshot metadata: [STATE.md](./STATE.md), [state.json](./.traderx-state/state.json)
- Source commit: https://github.com/finos/traderX/commit/7d6bc07efdfae09f19840f89a0270bfd0911467e
- Feature pack at source commit: https://github.com/finos/traderX/tree/7d6bc07efdfae09f19840f89a0270bfd0911467e/specs/001-baseline-uncontainerized-parity
- TraderSpec docs at source commit: https://github.com/finos/traderX/tree/7d6bc07efdfae09f19840f89a0270bfd0911467e/docs/traderspec
