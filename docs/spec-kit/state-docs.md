---
title: State Docs
hide_table_of_contents: true
---

# State Docs

This page is generated from `catalog/state-catalog.json` and links the most important per-state artifacts.

For progression context, see [Visual Learning Paths](/docs/spec-kit/visual-learning-graphs).

## State Catalog

| State | Status | Learning Guide | Spec Pack | Architecture | Flows / Topology | Generated Code Branch | Compare To Previous | ADR |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `001-baseline-uncontainerized-parity` | released | [link](/docs/learning/state-001-baseline-uncontainerized-parity) | [link](/specs/baseline-uncontainerized-parity) | [link](/specs/baseline-uncontainerized-parity/system/architecture) | [link](/specs/baseline-uncontainerized-parity/system/end-to-end-flows) | [code/generated-state-001-baseline-uncontainerized-parity](https://github.com/finos/traderX/tree/code/generated-state-001-baseline-uncontainerized-parity) | `n/a` | `n/a` |
| `002-edge-proxy-uncontainerized` | implemented | [link](/docs/learning/state-002-edge-proxy-uncontainerized) | [link](/specs/edge-proxy-uncontainerized) | [link](/specs/edge-proxy-uncontainerized/system/architecture) | [link](/specs/edge-proxy-uncontainerized/system/runtime-topology) | [code/generated-state-002-edge-proxy-uncontainerized](https://github.com/finos/traderX/tree/code/generated-state-002-edge-proxy-uncontainerized) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-001-baseline-uncontainerized-parity...code%2Fgenerated-state-002-edge-proxy-uncontainerized) | `n/a` |
| `003-containerized-compose-runtime` | implemented | [link](/docs/learning/state-003-containerized-compose-runtime) | [link](/specs/containerized-compose-runtime) | [link](/specs/containerized-compose-runtime/system/architecture) | [link](/specs/containerized-compose-runtime/system/runtime-topology) | [code/generated-state-003-containerized-compose-runtime](https://github.com/finos/traderX/tree/code/generated-state-003-containerized-compose-runtime) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-002-edge-proxy-uncontainerized...code%2Fgenerated-state-003-containerized-compose-runtime) | `n/a` |
| `004-kubernetes-runtime` | implemented | [link](/docs/learning/state-004-kubernetes-runtime) | [link](/specs/kubernetes-runtime) | [link](/specs/kubernetes-runtime/system/architecture) | [link](/specs/kubernetes-runtime/system/runtime-topology) | [code/generated-state-004-kubernetes-runtime](https://github.com/finos/traderX/tree/code/generated-state-004-kubernetes-runtime) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-003-containerized-compose-runtime...code%2Fgenerated-state-004-kubernetes-runtime) | `n/a` |
| `005-radius-kubernetes-platform` | implemented | [link](/docs/learning/state-005-radius-kubernetes-platform) | [link](/specs/radius-kubernetes-platform) | [link](/specs/radius-kubernetes-platform/system/architecture) | [link](/specs/radius-kubernetes-platform/system/runtime-topology) | [code/generated-state-005-radius-kubernetes-platform](https://github.com/finos/traderX/tree/code/generated-state-005-radius-kubernetes-platform) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-004-kubernetes-runtime...code%2Fgenerated-state-005-radius-kubernetes-platform) | `n/a` |
| `006-tilt-kubernetes-dev-loop` | implemented | [link](/docs/learning/state-006-tilt-kubernetes-dev-loop) | [link](/specs/tilt-kubernetes-dev-loop) | [link](/specs/tilt-kubernetes-dev-loop/system/architecture) | [link](/specs/tilt-kubernetes-dev-loop/system/runtime-topology) | [code/generated-state-006-tilt-kubernetes-dev-loop](https://github.com/finos/traderX/tree/code/generated-state-006-tilt-kubernetes-dev-loop) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-004-kubernetes-runtime...code%2Fgenerated-state-006-tilt-kubernetes-dev-loop) | `n/a` |
| `007-messaging-nats-replacement` | implemented | [link](/docs/learning/state-007-messaging-nats-replacement) | [link](/specs/messaging-nats-replacement) | [link](/specs/messaging-nats-replacement/system/architecture) | [link](/specs/messaging-nats-replacement/system/runtime-topology) | [code/generated-state-007-messaging-nats-replacement](https://github.com/finos/traderX/tree/code/generated-state-007-messaging-nats-replacement) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-003-containerized-compose-runtime...code%2Fgenerated-state-007-messaging-nats-replacement) | [link](/docs/adr/005-state-007-use-nats-for-messaging-replacement) |
| `009-postgres-database-replacement` | implemented | [link](/docs/learning/state-009-postgres-database-replacement) | [link](/specs/postgres-database-replacement) | [link](/specs/postgres-database-replacement/system/architecture) | [link](/specs/postgres-database-replacement/system/runtime-topology) | [code/generated-state-009-postgres-database-replacement](https://github.com/finos/traderX/tree/code/generated-state-009-postgres-database-replacement) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-003-containerized-compose-runtime...code%2Fgenerated-state-009-postgres-database-replacement) | [link](/docs/adr/006-state-009-use-postgres-for-database-replacement) |
| `010-pricing-awareness-market-data` | implemented | [link](/docs/learning/state-010-pricing-awareness-market-data) | [link](/specs/pricing-awareness-market-data) | [link](/specs/pricing-awareness-market-data/system/architecture) | [link](/specs/pricing-awareness-market-data/system/runtime-topology) | [code/generated-state-010-pricing-awareness-market-data](https://github.com/finos/traderX/tree/code/generated-state-010-pricing-awareness-market-data) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-007-messaging-nats-replacement...code%2Fgenerated-state-010-pricing-awareness-market-data) | `n/a` |

## API Explorer by State

- Current API explorer route: [/api](/api)
- Current scope: `001-baseline-uncontainerized-parity`
- Source contracts: `specs/001-baseline-uncontainerized-parity/contracts/**/openapi.yaml`
- Future plan: add per-state API explorer selectors as additional state contract sets are published.

## How This Page Is Maintained

- Source catalog: `catalog/state-catalog.json`
- Regenerate docs pages:

```bash
node pipeline/generate-state-docs-from-catalog.mjs
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
