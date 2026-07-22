# TraderX Generated Code Snapshot

This branch is an auto-published generated-code snapshot for FINOS TraderX.

![linux/mac support](https://badgen.net/badge/linux%2Fmac/supported/green?icon=linux) ![windows support](https://badgen.net/badge/windows/not%20supported/red?icon=windows)

- State ID: `008-pricing-awareness-market-data`
- State Title: `Pricing Awareness and Market Data Streaming`
- Status: `implemented`
- Suggested Version Tag: `generated/008-pricing-awareness-market-data/v1`
- Source Branch: `main`
- Source Commit: `f218c8e024a7c6adb89437678d03747b60ada083`
- Generated At (UTC): `2026-07-22T15:58:07Z`

## State Summary

- Builds on state `007` and preserves NATS-based messaging + compose ingress runtime behavior.
- Adds market pricing stream, trade execution price stamping, and position average cost basis aggregation.
- Extends UI blotters with pricing/value/P&L visualization while preserving baseline trade/account workflows.

## State Lineage

```mermaid
flowchart LR
  S_CUR["008-pricing-awareness-market-data (current)"]
  style S_CUR fill:#2e7d32,stroke:#1b5e20,color:#ffffff,stroke-width:2px
  S_PREV_007_observability_lgtm_compose["007-observability-lgtm-compose"] --> S_CUR
  click S_PREV_007_observability_lgtm_compose href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-007-observability-lgtm-compose" "Open branch"
  S_CUR --> S_NEXT_009_order_management_matcher["009-order-management-matcher"]
  click S_NEXT_009_order_management_matcher href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-009-order-management-matcher" "Open branch"
  click S_CUR href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-008-pricing-awareness-market-data" "Open current branch"
```

| Direction | State | Branch | Compare |
| --- | --- | --- | --- |
| Previous | `007-observability-lgtm-compose` | [code/generated-state-007-observability-lgtm-compose](https://github.com/finos/traderX/tree/code%2Fgenerated-state-007-observability-lgtm-compose) | 🔍 [compare](https://github.com/finos/traderX/compare/code%2Fgenerated-state-007-observability-lgtm-compose...code%2Fgenerated-state-008-pricing-awareness-market-data) |
| Next | `009-order-management-matcher` | [code/generated-state-009-order-management-matcher](https://github.com/finos/traderX/tree/code%2Fgenerated-state-009-order-management-matcher) | 🔍 [compare](https://github.com/finos/traderX/compare/code%2Fgenerated-state-008-pricing-awareness-market-data...code%2Fgenerated-state-009-order-management-matcher) |

State sets:
- Previous states: `007-observability-lgtm-compose`
- Next states: `009-order-management-matcher`

## Convergence Status

- Convergence state: `false`
- Convergence level: `none`
- Lineage role: `canonical`
- Dotted-line parents: `none`
- Previous convergence milestone: [007-observability-lgtm-compose](https://github.com/finos/traderX/tree/code%2Fgenerated-state-007-observability-lgtm-compose) (🔍 [compare](https://github.com/finos/traderX/compare/code%2Fgenerated-state-007-observability-lgtm-compose...code%2Fgenerated-state-008-pricing-awareness-market-data))
- Next convergence milestone: [009-order-management-matcher](https://github.com/finos/traderX/tree/code%2Fgenerated-state-009-order-management-matcher) (🔍 [compare](https://github.com/finos/traderX/compare/code%2Fgenerated-state-008-pricing-awareness-market-data...code%2Fgenerated-state-009-order-management-matcher))

### Convergence Neighborhood

```mermaid
flowchart LR
  C_CUR["008-pricing-awareness-market-data (current)"]
  style C_CUR fill:#2e7d32,stroke:#1b5e20,color:#ffffff,stroke-width:2px
  C_PREV_007_observability_lgtm_compose["007-observability-lgtm-compose"] --> C_CUR
  click C_PREV_007_observability_lgtm_compose href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-007-observability-lgtm-compose" "Open branch"
  %% compare: https://github.com/finos/traderX/compare/code%2Fgenerated-state-007-observability-lgtm-compose...code%2Fgenerated-state-008-pricing-awareness-market-data
  C_CUR --> C_NEXT_009_order_management_matcher["009-order-management-matcher"]
  click C_NEXT_009_order_management_matcher href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-009-order-management-matcher" "Open branch"
  %% compare: https://github.com/finos/traderX/compare/code%2Fgenerated-state-008-pricing-awareness-market-data...code%2Fgenerated-state-009-order-management-matcher
  click C_CUR href "https://github.com/finos/traderX/tree/code%2Fgenerated-state-008-pricing-awareness-market-data" "Open current branch"
```

## Runtime Guidance

Run directly from this generated snapshot branch:

```bash
./scripts/start-state-008-pricing-awareness-market-data-generated.sh
```

UI/ingress endpoint: `http://localhost:8080`
NATS monitor endpoint: `http://localhost:8222/varz`
Price publisher endpoint: `http://localhost:18100/prices`

Smoke test:

```bash
./scripts/test-state-008-pricing-awareness-market-data.sh
./scripts/test-state-008-pricing-awareness-market-data.sh --skip-messaging
./scripts/test-messaging-008-pricing-awareness-market-data.sh
```

Status / stop:

```bash
./scripts/status-state-008-pricing-awareness-market-data-generated.sh
./scripts/stop-state-008-pricing-awareness-market-data-generated.sh
```

## API Explorer

- API explorer (ingress): `http://localhost:8080/api/docs`

## Interactive URLs

- UI (ingress): `http://localhost:8080`
- API explorer (ingress): `http://localhost:8080/api/docs`
- Grafana dashboards (ingress): `http://localhost:8080/grafana/`
- Grafana local admin: `http://localhost:3001`
- Prometheus: `http://localhost:9090`
- Trade service Swagger: `http://localhost:18092/v3/api-docs`
- Price publisher health: `http://localhost:18100/health`

## Grafana Access

- Public dashboards: `http://localhost:8080/grafana/`
- Local admin URL: `http://localhost:3001`
- The start script prints the active local admin credential.
- Default convention: user from `TRADERX_GRAFANA_ADMIN_USER` or `traderx-admin`; password from `TRADERX_GRAFANA_ADMIN_PASSWORD` or `traderx-state-008`.

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

- Feature pack: `specs/008-pricing-awareness-market-data`
- Generation entrypoint: `bash pipeline/generate-state.sh 008-pricing-awareness-market-data`
- Developer learning guide for this snapshot: [LEARNING.md](./LEARNING.md)
- Functional validation guide: [FUNCTIONAL_TESTING.md](./FUNCTIONAL_TESTING.md)
- Snapshot metadata: [STATE.md](./STATE.md), [state.json](./.traderx-state/state.json)
- Canonical Getting Started (main): https://github.com/finos/traderX/blob/main/docs/spec-kit/getting-started-with-traderx.md
- Source commit: https://github.com/finos/traderX/commit/f218c8e024a7c6adb89437678d03747b60ada083
- Feature pack at source commit: https://github.com/finos/traderX/tree/f218c8e024a7c6adb89437678d03747b60ada083/specs/008-pricing-awareness-market-data
- SpecKit docs at source commit: https://github.com/finos/traderX/tree/f218c8e024a7c6adb89437678d03747b60ada083/docs/spec-kit
