# TraderX Generated Code Snapshot

This branch is an auto-published generated-code snapshot for FINOS TraderX.

![linux/mac support](https://badgen.net/badge/linux%2Fmac/supported/green?icon=linux) ![windows support](https://badgen.net/badge/windows/not%20supported/red?icon=windows)

- State ID: `013-radius-kubernetes-platform`
- State Title: `Radius Platform on Kubernetes (Optional)`
- Status: `implemented`
- Suggested Version Tag: `generated/013-radius-kubernetes-platform/v1`
- Source Branch: `codex/address-actions-cves-20260528`
- Source Commit: `b311f3fe944207a4497a20cb5ed1a9529a004eab`
- Generated At (UTC): `2026-05-28T05:33:21Z`

## State Summary

- Builds on state `010` and preserves Kubernetes runtime behavior.
- Adds Radius application/resource model artifacts as platform abstraction overlays.
- Preserves baseline functional behavior and API contracts.

## State Lineage

```mermaid
flowchart LR
  S_CUR["013-radius-kubernetes-platform (current)"]
  style S_CUR fill:#2e7d32,stroke:#1b5e20,color:#ffffff,stroke-width:2px
  S_PREV_012_platform_convergence_c3["012-platform-convergence-c3"] --> S_CUR
  click S_PREV_012_platform_convergence_c3 href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-012-platform-convergence-c3" "Open branch"
  click S_CUR href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-013-radius-kubernetes-platform" "Open current branch"
```

| Direction | State | Branch | Compare |
| --- | --- | --- | --- |
| Previous | `012-platform-convergence-c3` | [code/generated-state-012-platform-convergence-c3](https://github.com/finos/traderX/tree/code%2Fgenerated-state-012-platform-convergence-c3) | 🔍 [compare](https://github.com/finos/traderX/compare/code%2Fgenerated-state-012-platform-convergence-c3...code%2Fgenerated-state-013-radius-kubernetes-platform) |

State sets:
- Previous states: `012-platform-convergence-c3`
- Next states: `none`

## Convergence Status

- Convergence state: `false`
- Convergence level: `none`
- Lineage role: `optional`
- Dotted-line parents: `none`
- Previous convergence milestone: [012-platform-convergence-c3](https://github.com/finos/traderX/tree/code%2Fgenerated-state-012-platform-convergence-c3) (🔍 [compare](https://github.com/finos/traderX/compare/code%2Fgenerated-state-012-platform-convergence-c3...code%2Fgenerated-state-013-radius-kubernetes-platform))
- Next convergence milestone: `none`

### Convergence Neighborhood

```mermaid
flowchart LR
  C_CUR["013-radius-kubernetes-platform (current)"]
  style C_CUR fill:#2e7d32,stroke:#1b5e20,color:#ffffff,stroke-width:2px
  C_PREV_012_platform_convergence_c3["012-platform-convergence-c3"] --> C_CUR
  click C_PREV_012_platform_convergence_c3 href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-012-platform-convergence-c3" "Open branch"
  %% compare: https://github.com/finos/traderX/compare/code%2Fgenerated-state-012-platform-convergence-c3...code%2Fgenerated-state-013-radius-kubernetes-platform
  click C_CUR href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-013-radius-kubernetes-platform" "Open current branch"
```

## Runtime Guidance

Run directly from this generated snapshot branch:

```bash
./scripts/start-state-010-kubernetes-runtime-generated.sh --provider kind
```

UI/edge endpoint: `http://localhost:8080`

Radius artifact pack:

- `radius-kubernetes-platform/radius/app.bicep`
- `radius-kubernetes-platform/radius/bicepconfig.json`

Status / stop:

```bash
./scripts/status-state-010-kubernetes-runtime-generated.sh --provider kind
./scripts/stop-state-010-kubernetes-runtime-generated.sh --provider kind
```

## API Explorer

- API explorer (ingress): `http://localhost:8080/api/docs`

## Interactive URLs

- UI (ingress): `http://localhost:8080`
- API explorer (ingress): `http://localhost:8080/api/docs`
- Trade page: `http://localhost:8080/trade`
- Account service route: `http://localhost:8080/account-service/account/22214`
- Position service route: `http://localhost:8080/position-service/positions/22214`
- Grafana (ingress): `http://localhost:8080/grafana` (admin/admin)
- Prometheus (ingress): `http://localhost:8080/prometheus`

Detailed clone-first instructions: [RUN_FROM_CLONE.md](./RUN_FROM_CLONE.md)
Functional validation guide: [FUNCTIONAL_TESTING.md](./FUNCTIONAL_TESTING.md)

## Learning Docs In This Snapshot

- [Docs Index](./docs/README.md)
- [Learning Index](./docs/learning/README.md)
- [Component List](./docs/learning/component-list.md)
- [System Design](./docs/learning/system-design.md)
- [Software Architecture](./docs/learning/software-architecture.md)
- [Component Diagram](./docs/learning/component-diagram.md)

## Canonical Specs And Docs

Canonical source-of-truth is maintained in the SpecKit authoring branch, not in this code snapshot branch.

- Feature pack: `specs/013-radius-kubernetes-platform`
- Generation entrypoint: `bash pipeline/generate-state.sh 013-radius-kubernetes-platform`
- Developer learning guide for this snapshot: [LEARNING.md](./LEARNING.md)
- Functional validation guide: [FUNCTIONAL_TESTING.md](./FUNCTIONAL_TESTING.md)
- Snapshot metadata: [STATE.md](./STATE.md), [state.json](./.traderx-state/state.json)
- Canonical Getting Started (main): https://github.com/finos/traderX/blob/main/docs/spec-kit/getting-started-with-traderx.md
- Source commit: https://github.com/finos/traderX/commit/b311f3fe944207a4497a20cb5ed1a9529a004eab
- Feature pack at source commit: https://github.com/finos/traderX/tree/b311f3fe944207a4497a20cb5ed1a9529a004eab/specs/013-radius-kubernetes-platform
- SpecKit docs at source commit: https://github.com/finos/traderX/tree/b311f3fe944207a4497a20cb5ed1a9529a004eab/docs/spec-kit
