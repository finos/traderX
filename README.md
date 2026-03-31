# TraderX Generated Code Snapshot

This branch is an auto-published generated-code snapshot for FINOS TraderX.

- State ID: `005-radius-kubernetes-platform`
- State Title: `Radius Platform on Kubernetes`
- Status: `implemented`
- Suggested Version Tag: `generated/005-radius-kubernetes-platform/v1`
- Source Branch: `feature/agentic-renovation`
- Source Commit: `68d19a554c7480a615b19c024eb0a88228c6b9ad`
- Generated At (UTC): `2026-03-31T13:09:17Z`

## State Summary

- Builds on state `004` and preserves Kubernetes runtime behavior.
- Adds Radius application/resource model artifacts as platform abstraction overlays.
- Preserves baseline functional behavior and API contracts.

## State Lineage

```mermaid
flowchart LR
  S_CUR["005-radius-kubernetes-platform (current)"]
  style S_CUR fill:#2e7d32,stroke:#1b5e20,color:#ffffff,stroke-width:2px
  S_PREV_004_kubernetes_runtime["004-kubernetes-runtime"] --> S_CUR
  click S_PREV_004_kubernetes_runtime href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-004-kubernetes-runtime" "Open branch"
  click S_CUR href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-005-radius-kubernetes-platform" "Open current branch"
```

| Direction | State | Branch | Compare |
| --- | --- | --- | --- |
| Previous | `004-kubernetes-runtime` | [code/generated-state-004-kubernetes-runtime](https://github.com/finos/traderX/tree/code%2Fgenerated-state-004-kubernetes-runtime) | 🔍 [compare](https://github.com/finos/traderX/compare/code%2Fgenerated-state-004-kubernetes-runtime...code%2Fgenerated-state-005-radius-kubernetes-platform) |

State sets:
- Previous states: `004-kubernetes-runtime`
- Next states: `none`

## Runtime Guidance

Run directly from this generated snapshot branch:

```bash
./scripts/start-state-004-kubernetes-generated.sh --provider kind
```

UI/edge endpoint: `http://localhost:8080`

Radius artifact pack:

- `radius-kubernetes-platform/radius/app.bicep`
- `radius-kubernetes-platform/radius/bicepconfig.json`

Status / stop:

```bash
./scripts/status-state-004-kubernetes-generated.sh --provider kind
./scripts/stop-state-004-kubernetes-generated.sh --provider kind
```

Detailed clone-first instructions: [RUN_FROM_CLONE.md](./RUN_FROM_CLONE.md)

## Learning Docs In This Snapshot

- [Docs Index](./docs/README.md)
- [Learning Index](./docs/learning/README.md)
- [Component List](./docs/learning/component-list.md)
- [System Design](./docs/learning/system-design.md)
- [Software Architecture](./docs/learning/software-architecture.md)
- [Component Diagram](./docs/learning/component-diagram.md)

## Canonical Specs And Docs

Canonical source-of-truth is maintained in the SpecKit authoring branch, not in this code snapshot branch.

- Feature pack: `specs/005-radius-kubernetes-platform`
- Generation entrypoint: `bash pipeline/generate-state.sh 005-radius-kubernetes-platform`
- Developer learning guide for this snapshot: [LEARNING.md](./LEARNING.md)
- Snapshot metadata: [STATE.md](./STATE.md), [state.json](./.traderx-state/state.json)
- Source commit: https://github.com/finos/traderX/commit/68d19a554c7480a615b19c024eb0a88228c6b9ad
- Feature pack at source commit: https://github.com/finos/traderX/tree/68d19a554c7480a615b19c024eb0a88228c6b9ad/specs/005-radius-kubernetes-platform
- SpecKit docs at source commit: https://github.com/finos/traderX/tree/68d19a554c7480a615b19c024eb0a88228c6b9ad/docs/spec-kit
