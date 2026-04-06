---
title: State Docs
hide_table_of_contents: true
---

# State Docs

This page is generated from `catalog/state-catalog.json` and links the most important per-state artifacts.

For progression context, see [Visual Learning Paths](/docs/learning-paths).

## State Catalog

| State | Status | Convergence | Dotted Parents | Learning Guide | Spec Pack | Architecture | Flows / Topology | Research | Data Model | Quickstart | Generated Code Branch | Compare To Previous | ADR |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `001-baseline-uncontainerized-parity` | released | `none` | `none` | [link](/docs/learning/state-001-baseline-uncontainerized-parity) | [link](/specs/baseline-uncontainerized-parity) | [link](/specs/baseline-uncontainerized-parity/system/architecture) | [link](/specs/baseline-uncontainerized-parity/system/end-to-end-flows) | [link](/specs/baseline-uncontainerized-parity/research) | [link](/specs/baseline-uncontainerized-parity/data-model) | [link](/specs/baseline-uncontainerized-parity/quickstart) | [code/generated-state-001-baseline-uncontainerized-parity](https://github.com/finos/traderX/tree/code/generated-state-001-baseline-uncontainerized-parity) | `n/a` | `n/a` |
| `002-edge-proxy-uncontainerized` | implemented | `none` | `none` | [link](/docs/learning/state-002-edge-proxy-uncontainerized) | [link](/specs/edge-proxy-uncontainerized) | [link](/specs/edge-proxy-uncontainerized/system/architecture) | [link](/specs/edge-proxy-uncontainerized/system/runtime-topology) | [link](/specs/edge-proxy-uncontainerized/research) | [link](/specs/edge-proxy-uncontainerized/data-model) | [link](/specs/edge-proxy-uncontainerized/quickstart) | [code/generated-state-002-edge-proxy-uncontainerized](https://github.com/finos/traderX/tree/code/generated-state-002-edge-proxy-uncontainerized) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-001-baseline-uncontainerized-parity...code%2Fgenerated-state-002-edge-proxy-uncontainerized) | `n/a` |
| `003-containerized-compose-runtime` | implemented | `C0` | `none` | [link](/docs/learning/state-003-containerized-compose-runtime) | [link](/specs/containerized-compose-runtime) | [link](/specs/containerized-compose-runtime/system/architecture) | [link](/specs/containerized-compose-runtime/system/runtime-topology) | [link](/specs/containerized-compose-runtime/research) | [link](/specs/containerized-compose-runtime/data-model) | [link](/specs/containerized-compose-runtime/quickstart) | [code/generated-state-003-containerized-compose-runtime](https://github.com/finos/traderX/tree/code/generated-state-003-containerized-compose-runtime) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-002-edge-proxy-uncontainerized...code%2Fgenerated-state-003-containerized-compose-runtime) | `n/a` |
| `004-postgres-database-replacement` | implemented | `none` | `none` | [link](/docs/learning/state-004-postgres-database-replacement) | [link](/specs/postgres-database-replacement) | [link](/specs/postgres-database-replacement/system/architecture) | [link](/specs/postgres-database-replacement/system/runtime-topology) | [link](/specs/postgres-database-replacement/research) | [link](/specs/postgres-database-replacement/data-model) | [link](/specs/postgres-database-replacement/quickstart) | [code/generated-state-004-postgres-database-replacement](https://github.com/finos/traderX/tree/code/generated-state-004-postgres-database-replacement) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-003-containerized-compose-runtime...code%2Fgenerated-state-004-postgres-database-replacement) | [link](/docs/adr/006-state-004-use-postgres-for-database-replacement) |
| `005-messaging-nats-replacement` | implemented | `none` | `none` | [link](/docs/learning/state-005-messaging-nats-replacement) | [link](/specs/messaging-nats-replacement) | [link](/specs/messaging-nats-replacement/system/architecture) | [link](/specs/messaging-nats-replacement/system/runtime-topology) | [link](/specs/messaging-nats-replacement/research) | [link](/specs/messaging-nats-replacement/data-model) | [link](/specs/messaging-nats-replacement/quickstart) | [code/generated-state-005-messaging-nats-replacement](https://github.com/finos/traderX/tree/code/generated-state-005-messaging-nats-replacement) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-004-postgres-database-replacement...code%2Fgenerated-state-005-messaging-nats-replacement) | [link](/docs/adr/005-state-005-use-nats-for-messaging-replacement) |
| `006-observability-lgtm-compose` | implemented | `C1` | `none` | [link](/docs/learning/state-006-observability-lgtm-compose) | [link](/specs/observability-lgtm-compose) | [link](/specs/observability-lgtm-compose/system/architecture) | [link](/specs/observability-lgtm-compose/system/runtime-topology) | [link](/specs/observability-lgtm-compose/research) | [link](/specs/observability-lgtm-compose/data-model) | [link](/specs/observability-lgtm-compose/quickstart) | [code/generated-state-006-observability-lgtm-compose](https://github.com/finos/traderX/tree/code/generated-state-006-observability-lgtm-compose) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-005-messaging-nats-replacement...code%2Fgenerated-state-006-observability-lgtm-compose) | [link](/docs/adr/007-state-006-adopt-lgtm-observability-stack) |
| `007-pricing-awareness-market-data` | implemented | `none` | `none` | [link](/docs/learning/state-007-pricing-awareness-market-data) | [link](/specs/pricing-awareness-market-data) | [link](/specs/pricing-awareness-market-data/system/architecture) | [link](/specs/pricing-awareness-market-data/system/runtime-topology) | [link](/specs/pricing-awareness-market-data/research) | [link](/specs/pricing-awareness-market-data/data-model) | [link](/specs/pricing-awareness-market-data/quickstart) | [code/generated-state-007-pricing-awareness-market-data](https://github.com/finos/traderX/tree/code/generated-state-007-pricing-awareness-market-data) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-006-observability-lgtm-compose...code%2Fgenerated-state-007-pricing-awareness-market-data) | `n/a` |
| `008-order-management-matcher` | implemented | `C2` | `none` | [link](/docs/learning/state-008-order-management-matcher) | [link](/specs/order-management-matcher) | [link](/specs/order-management-matcher/system/architecture) | [link](/specs/order-management-matcher/system/runtime-topology) | [link](/specs/order-management-matcher/research) | [link](/specs/order-management-matcher/data-model) | [link](/specs/order-management-matcher/quickstart) | [code/generated-state-008-order-management-matcher](https://github.com/finos/traderX/tree/code/generated-state-008-order-management-matcher) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-007-pricing-awareness-market-data...code%2Fgenerated-state-008-order-management-matcher) | `n/a` |
| `009-kubernetes-runtime` | implemented | `none` | `none` | [link](/docs/learning/state-009-kubernetes-runtime) | [link](/specs/kubernetes-runtime) | [link](/specs/kubernetes-runtime/system/architecture) | [link](/specs/kubernetes-runtime/system/runtime-topology) | [link](/specs/kubernetes-runtime/research) | [link](/specs/kubernetes-runtime/data-model) | [link](/specs/kubernetes-runtime/quickstart) | [code/generated-state-009-kubernetes-runtime](https://github.com/finos/traderX/tree/code/generated-state-009-kubernetes-runtime) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-008-order-management-matcher...code%2Fgenerated-state-009-kubernetes-runtime) | `n/a` |
| `010-tilt-kubernetes-dev-loop` | implemented | `none` | `none` | [link](/docs/learning/state-010-tilt-kubernetes-dev-loop) | [link](/specs/tilt-kubernetes-dev-loop) | [link](/specs/tilt-kubernetes-dev-loop/system/architecture) | [link](/specs/tilt-kubernetes-dev-loop/system/runtime-topology) | [link](/specs/tilt-kubernetes-dev-loop/research) | [link](/specs/tilt-kubernetes-dev-loop/data-model) | [link](/specs/tilt-kubernetes-dev-loop/quickstart) | [code/generated-state-010-tilt-kubernetes-dev-loop](https://github.com/finos/traderX/tree/code/generated-state-010-tilt-kubernetes-dev-loop) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-009-kubernetes-runtime...code%2Fgenerated-state-010-tilt-kubernetes-dev-loop) | `n/a` |
| `011-platform-convergence-c3` | implemented | `C3` | [008-order-management-matcher](/docs/learning/state-008-order-management-matcher) | [link](/docs/learning/state-011-platform-convergence-c3) | [link](/specs/platform-convergence-c3) | [link](/specs/platform-convergence-c3/system/architecture) | [link](/specs/platform-convergence-c3/system/runtime-topology) | [link](/specs/platform-convergence-c3/research) | [link](/specs/platform-convergence-c3/data-model) | [link](/specs/platform-convergence-c3/quickstart) | [code/generated-state-011-platform-convergence-c3](https://github.com/finos/traderX/tree/code/generated-state-011-platform-convergence-c3) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-010-tilt-kubernetes-dev-loop...code%2Fgenerated-state-011-platform-convergence-c3) | [link](/docs/adr/008-convergence-state-model) |
| `012-radius-kubernetes-platform` | implemented | `none` | `none` | [link](/docs/learning/state-012-radius-kubernetes-platform) | [link](/specs/radius-kubernetes-platform) | [link](/specs/radius-kubernetes-platform/system/architecture) | [link](/specs/radius-kubernetes-platform/system/runtime-topology) | [link](/specs/radius-kubernetes-platform/research) | [link](/specs/radius-kubernetes-platform/data-model) | [link](/specs/radius-kubernetes-platform/quickstart) | [code/generated-state-012-radius-kubernetes-platform](https://github.com/finos/traderX/tree/code/generated-state-012-radius-kubernetes-platform) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-009-kubernetes-runtime...code%2Fgenerated-state-012-radius-kubernetes-platform) | `n/a` |

## API Explorer by State

- Current API explorer route: [/api](/api)
- Current scope: `001-baseline-uncontainerized-parity`
- Source contracts: `specs/001-baseline-uncontainerized-parity/contracts/**/openapi.yaml`
- Future plan: add per-state API explorer selectors as additional state contract sets are published.

## How This Page Is Maintained

- Source catalog: `catalog/state-catalog.json`
- Regenerate docs pages:

```bash
bash pipeline/refresh-state-docs.sh
```

- State architecture docs are generated from:
  - `specs/<state>/system/architecture.model.json`
- Generate state architecture docs:

```bash
bash pipeline/generate-state-architecture-doc.sh <state-id>
```

- Generate all state architecture docs:

```bash
bash pipeline/generate-all-architecture-docs.sh
```
