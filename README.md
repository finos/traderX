# TraderX Generated Code Snapshot

This branch is an auto-published generated-code snapshot for FINOS TraderX.

![linux/mac support](https://badgen.net/badge/linux%2Fmac/supported/green?icon=linux) ![windows support](https://badgen.net/badge/windows/not%20supported/red?icon=windows)

- State ID: `010-kubernetes-runtime`
- State Title: `Kubernetes Runtime on C2`
- Status: `implemented`
- Suggested Version Tag: `generated/010-kubernetes-runtime/v1`
- Source Branch: `main`
- Source Commit: `f60def6eff9b988141d59ae6ad864dfd5bc10ce6`
- Generated At (UTC): `2026-07-22T16:51:51Z`

## State Summary

- Builds on state `009` by moving runtime from Docker Compose to Kubernetes (Kind baseline).
- Uses in-cluster NGINX edge-proxy as browser/API/WebSocket entrypoint at `http://localhost:8080`.
- Preserves C2 functional behavior while changing runtime orchestration and deployment model.

## State Lineage

```mermaid
flowchart LR
  S_CUR["010-kubernetes-runtime (current)"]
  style S_CUR fill:#2e7d32,stroke:#1b5e20,color:#ffffff,stroke-width:2px
  S_PREV_009_order_management_matcher["009-order-management-matcher"] --> S_CUR
  click S_PREV_009_order_management_matcher href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-009-order-management-matcher" "Open branch"
  S_CUR --> S_NEXT_011_tilt_kubernetes_dev_loop["011-tilt-kubernetes-dev-loop"]
  click S_NEXT_011_tilt_kubernetes_dev_loop href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-011-tilt-kubernetes-dev-loop" "Open branch"
  click S_CUR href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-010-kubernetes-runtime" "Open current branch"
```

| Direction | State | Branch | Compare |
| --- | --- | --- | --- |
| Previous | `009-order-management-matcher` | [code/generated-state-009-order-management-matcher](https://github.com/finos/traderX/tree/code%2Fgenerated-state-009-order-management-matcher) | 🔍 [compare](https://github.com/finos/traderX/compare/code%2Fgenerated-state-009-order-management-matcher...code%2Fgenerated-state-010-kubernetes-runtime) |
| Next | `011-tilt-kubernetes-dev-loop` | [code/generated-state-011-tilt-kubernetes-dev-loop](https://github.com/finos/traderX/tree/code%2Fgenerated-state-011-tilt-kubernetes-dev-loop) | 🔍 [compare](https://github.com/finos/traderX/compare/code%2Fgenerated-state-010-kubernetes-runtime...code%2Fgenerated-state-011-tilt-kubernetes-dev-loop) |

State sets:
- Previous states: `009-order-management-matcher`
- Next states: `011-tilt-kubernetes-dev-loop`

## Convergence Status

- Convergence state: `false`
- Convergence level: `none`
- Lineage role: `canonical`
- Dotted-line parents: `none`
- Previous convergence milestone: [009-order-management-matcher](https://github.com/finos/traderX/tree/code%2Fgenerated-state-009-order-management-matcher) (🔍 [compare](https://github.com/finos/traderX/compare/code%2Fgenerated-state-009-order-management-matcher...code%2Fgenerated-state-010-kubernetes-runtime))
- Next convergence milestone: [012-platform-convergence-c3](https://github.com/finos/traderX/tree/code%2Fgenerated-state-012-platform-convergence-c3) (🔍 [compare](https://github.com/finos/traderX/compare/code%2Fgenerated-state-010-kubernetes-runtime...code%2Fgenerated-state-012-platform-convergence-c3))

### Convergence Neighborhood

```mermaid
flowchart LR
  C_CUR["010-kubernetes-runtime (current)"]
  style C_CUR fill:#2e7d32,stroke:#1b5e20,color:#ffffff,stroke-width:2px
  C_PREV_009_order_management_matcher["009-order-management-matcher"] --> C_CUR
  click C_PREV_009_order_management_matcher href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-009-order-management-matcher" "Open branch"
  %% compare: https://github.com/finos/traderX/compare/code%2Fgenerated-state-009-order-management-matcher...code%2Fgenerated-state-010-kubernetes-runtime
  C_CUR --> C_NEXT_012_platform_convergence_c3["012-platform-convergence-c3"]
  click C_NEXT_012_platform_convergence_c3 href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-012-platform-convergence-c3" "Open branch"
  %% compare: https://github.com/finos/traderX/compare/code%2Fgenerated-state-010-kubernetes-runtime...code%2Fgenerated-state-012-platform-convergence-c3
  click C_CUR href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-010-kubernetes-runtime" "Open current branch"
```

## Runtime Guidance

Run directly from this generated snapshot branch:

```bash
./scripts/start-state-010-kubernetes-runtime-generated.sh
```

UI/edge endpoint: `http://localhost:8080`

Status / stop:

```bash
./scripts/status-state-010-kubernetes-runtime-generated.sh
./scripts/stop-state-010-kubernetes-runtime-generated.sh
```

## API Explorer

- API explorer (ingress): `http://localhost:8080/api/docs`

## Interactive URLs

- UI (ingress): `http://localhost:8080`
- API explorer (ingress): `http://localhost:8080/api/docs`
- Trade page: `http://localhost:8080/trade`
- Account service route: `http://localhost:8080/account-service/account/22214`
- Position service route: `http://localhost:8080/position-service/positions/22214`
- Grafana (ingress): `http://localhost:8080/grafana`
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

- Feature pack: `specs/010-kubernetes-runtime`
- Generation entrypoint: `bash pipeline/generate-state.sh 010-kubernetes-runtime`
- Developer learning guide for this snapshot: [LEARNING.md](./LEARNING.md)
- Functional validation guide: [FUNCTIONAL_TESTING.md](./FUNCTIONAL_TESTING.md)
- Snapshot metadata: [STATE.md](./STATE.md), [state.json](./.traderx-state/state.json)
- Canonical Getting Started (main): https://github.com/finos/traderX/blob/main/docs/spec-kit/getting-started-with-traderx.md
- Source commit: https://github.com/finos/traderX/commit/f60def6eff9b988141d59ae6ad864dfd5bc10ce6
- Feature pack at source commit: https://github.com/finos/traderX/tree/f60def6eff9b988141d59ae6ad864dfd5bc10ce6/specs/010-kubernetes-runtime
- SpecKit docs at source commit: https://github.com/finos/traderX/tree/f60def6eff9b988141d59ae6ad864dfd5bc10ce6/docs/spec-kit
