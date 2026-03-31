---
title: Learning Guides
---

# Learning Guides

This section is the developer-focused learning layer for generated TraderX code states.

Canonical requirements, contracts, and architecture remain in `specs/**`.  
These guides explain how to read each generated code snapshot, compare it to previous states, and understand the code delta in plain English.

## State Guide Catalog

| State | Learning Guide | Spec Pack | Generated Code Branch | Previous State(s) | Compare To Previous | ADR |
| --- | --- | --- | --- | --- | --- | --- |
| `001-baseline-uncontainerized-parity` | [link](/docs/learning/state-001-baseline-uncontainerized-parity) | [link](/specs/baseline-uncontainerized-parity) | [code/generated-state-001-baseline-uncontainerized-parity](https://github.com/finos/traderX/tree/code/generated-state-001-baseline-uncontainerized-parity) | `none` | `n/a` | `n/a` |
| `002-edge-proxy-uncontainerized` | [link](/docs/learning/state-002-edge-proxy-uncontainerized) | [link](/specs/edge-proxy-uncontainerized) | [code/generated-state-002-edge-proxy-uncontainerized](https://github.com/finos/traderX/tree/code/generated-state-002-edge-proxy-uncontainerized) | [001-baseline-uncontainerized-parity](/docs/learning/state-001-baseline-uncontainerized-parity) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-001-baseline-uncontainerized-parity...code%2Fgenerated-state-002-edge-proxy-uncontainerized) | `n/a` |
| `003-containerized-compose-runtime` | [link](/docs/learning/state-003-containerized-compose-runtime) | [link](/specs/containerized-compose-runtime) | [code/generated-state-003-containerized-compose-runtime](https://github.com/finos/traderX/tree/code/generated-state-003-containerized-compose-runtime) | [002-edge-proxy-uncontainerized](/docs/learning/state-002-edge-proxy-uncontainerized) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-002-edge-proxy-uncontainerized...code%2Fgenerated-state-003-containerized-compose-runtime) | `n/a` |
| `004-kubernetes-runtime` | [link](/docs/learning/state-004-kubernetes-runtime) | [link](/specs/kubernetes-runtime) | [code/generated-state-004-kubernetes-runtime](https://github.com/finos/traderX/tree/code/generated-state-004-kubernetes-runtime) | [003-containerized-compose-runtime](/docs/learning/state-003-containerized-compose-runtime) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-003-containerized-compose-runtime...code%2Fgenerated-state-004-kubernetes-runtime) | `n/a` |
| `005-radius-kubernetes-platform` | [link](/docs/learning/state-005-radius-kubernetes-platform) | [link](/specs/radius-kubernetes-platform) | [code/generated-state-005-radius-kubernetes-platform](https://github.com/finos/traderX/tree/code/generated-state-005-radius-kubernetes-platform) | [004-kubernetes-runtime](/docs/learning/state-004-kubernetes-runtime) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-004-kubernetes-runtime...code%2Fgenerated-state-005-radius-kubernetes-platform) | `n/a` |
| `006-tilt-kubernetes-dev-loop` | [link](/docs/learning/state-006-tilt-kubernetes-dev-loop) | [link](/specs/tilt-kubernetes-dev-loop) | [code/generated-state-006-tilt-kubernetes-dev-loop](https://github.com/finos/traderX/tree/code/generated-state-006-tilt-kubernetes-dev-loop) | [004-kubernetes-runtime](/docs/learning/state-004-kubernetes-runtime) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-004-kubernetes-runtime...code%2Fgenerated-state-006-tilt-kubernetes-dev-loop) | `n/a` |
| `007-messaging-nats-replacement` | [link](/docs/learning/state-007-messaging-nats-replacement) | [link](/specs/messaging-nats-replacement) | [code/generated-state-007-messaging-nats-replacement](https://github.com/finos/traderX/tree/code/generated-state-007-messaging-nats-replacement) | [003-containerized-compose-runtime](/docs/learning/state-003-containerized-compose-runtime) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-003-containerized-compose-runtime...code%2Fgenerated-state-007-messaging-nats-replacement) | [link](/docs/adr/005-state-007-use-nats-for-messaging-replacement) |
| `009-postgres-database-replacement` | [link](/docs/learning/state-009-postgres-database-replacement) | [link](/specs/postgres-database-replacement) | [code/generated-state-009-postgres-database-replacement](https://github.com/finos/traderX/tree/code/generated-state-009-postgres-database-replacement) | [003-containerized-compose-runtime](/docs/learning/state-003-containerized-compose-runtime) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-003-containerized-compose-runtime...code%2Fgenerated-state-009-postgres-database-replacement) | [link](/docs/adr/006-state-009-use-postgres-for-database-replacement) |
| `010-pricing-awareness-market-data` | [link](/docs/learning/state-010-pricing-awareness-market-data) | [link](/specs/pricing-awareness-market-data) | [code/generated-state-010-pricing-awareness-market-data](https://github.com/finos/traderX/tree/code/generated-state-010-pricing-awareness-market-data) | [007-messaging-nats-replacement](/docs/learning/state-007-messaging-nats-replacement) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-007-messaging-nats-replacement...code%2Fgenerated-state-010-pricing-awareness-market-data) | `n/a` |

## How To Use This Section

1. Open a state guide from this catalog.
2. Use the GitHub compare link to inspect exact code changes against previous state(s).
3. Read the plain-English delta for rationale and intent.
4. Follow links back to spec architecture/flows/contracts when you need system context.
