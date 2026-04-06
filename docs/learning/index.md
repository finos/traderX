---
title: Learning Guides
---

# Learning Guides

This section is the developer-focused learning layer for generated TraderX code states.

Canonical requirements, contracts, and architecture remain in `specs/**`.  
These guides explain how to read each generated code snapshot, compare it to previous states, and understand the code delta in plain English.

For the visual progression map, see [Visual Learning Paths](/docs/spec-kit/visual-learning-graphs).

## State Guide Catalog

| State | Learning Guide | Spec Pack | Generated Code Branch | Convergence | Dotted Parents | Previous State(s) | Compare To Previous | ADR |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `001-baseline-uncontainerized-parity` | [link](/docs/learning/state-001-baseline-uncontainerized-parity) | [link](/specs/baseline-uncontainerized-parity) | [code/generated-state-001-baseline-uncontainerized-parity](https://github.com/finos/traderX/tree/code/generated-state-001-baseline-uncontainerized-parity) | `none` | `none` | `none` | `n/a` | `n/a` |
| `002-edge-proxy-uncontainerized` | [link](/docs/learning/state-002-edge-proxy-uncontainerized) | [link](/specs/edge-proxy-uncontainerized) | [code/generated-state-002-edge-proxy-uncontainerized](https://github.com/finos/traderX/tree/code/generated-state-002-edge-proxy-uncontainerized) | `none` | `none` | [001-baseline-uncontainerized-parity](/docs/learning/state-001-baseline-uncontainerized-parity) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-001-baseline-uncontainerized-parity...code%2Fgenerated-state-002-edge-proxy-uncontainerized) | `n/a` |
| `003-containerized-compose-runtime` | [link](/docs/learning/state-003-containerized-compose-runtime) | [link](/specs/containerized-compose-runtime) | [code/generated-state-003-containerized-compose-runtime](https://github.com/finos/traderX/tree/code/generated-state-003-containerized-compose-runtime) | `C0` | `none` | [002-edge-proxy-uncontainerized](/docs/learning/state-002-edge-proxy-uncontainerized) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-002-edge-proxy-uncontainerized...code%2Fgenerated-state-003-containerized-compose-runtime) | `n/a` |
| `004-postgres-database-replacement` | [link](/docs/learning/state-004-postgres-database-replacement) | [link](/specs/postgres-database-replacement) | [code/generated-state-004-postgres-database-replacement](https://github.com/finos/traderX/tree/code/generated-state-004-postgres-database-replacement) | `none` | `none` | [003-containerized-compose-runtime](/docs/learning/state-003-containerized-compose-runtime) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-003-containerized-compose-runtime...code%2Fgenerated-state-004-postgres-database-replacement) | [link](/docs/adr/006-state-004-use-postgres-for-database-replacement) |
| `005-messaging-nats-replacement` | [link](/docs/learning/state-005-messaging-nats-replacement) | [link](/specs/messaging-nats-replacement) | [code/generated-state-005-messaging-nats-replacement](https://github.com/finos/traderX/tree/code/generated-state-005-messaging-nats-replacement) | `none` | `none` | [004-postgres-database-replacement](/docs/learning/state-004-postgres-database-replacement) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-004-postgres-database-replacement...code%2Fgenerated-state-005-messaging-nats-replacement) | [link](/docs/adr/005-state-005-use-nats-for-messaging-replacement) |
| `006-observability-lgtm-compose` | [link](/docs/learning/state-006-observability-lgtm-compose) | [link](/specs/observability-lgtm-compose) | [code/generated-state-006-observability-lgtm-compose](https://github.com/finos/traderX/tree/code/generated-state-006-observability-lgtm-compose) | `C1` | `none` | [005-messaging-nats-replacement](/docs/learning/state-005-messaging-nats-replacement) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-005-messaging-nats-replacement...code%2Fgenerated-state-006-observability-lgtm-compose) | [link](/docs/adr/007-state-006-adopt-lgtm-observability-stack) |
| `007-pricing-awareness-market-data` | [link](/docs/learning/state-007-pricing-awareness-market-data) | [link](/specs/pricing-awareness-market-data) | [code/generated-state-007-pricing-awareness-market-data](https://github.com/finos/traderX/tree/code/generated-state-007-pricing-awareness-market-data) | `none` | `none` | [006-observability-lgtm-compose](/docs/learning/state-006-observability-lgtm-compose) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-006-observability-lgtm-compose...code%2Fgenerated-state-007-pricing-awareness-market-data) | `n/a` |
| `008-order-management-matcher` | [link](/docs/learning/state-008-order-management-matcher) | [link](/specs/order-management-matcher) | [code/generated-state-008-order-management-matcher](https://github.com/finos/traderX/tree/code/generated-state-008-order-management-matcher) | `C2` | `none` | [007-pricing-awareness-market-data](/docs/learning/state-007-pricing-awareness-market-data) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-007-pricing-awareness-market-data...code%2Fgenerated-state-008-order-management-matcher) | `n/a` |
| `009-kubernetes-runtime` | [link](/docs/learning/state-009-kubernetes-runtime) | [link](/specs/kubernetes-runtime) | [code/generated-state-009-kubernetes-runtime](https://github.com/finos/traderX/tree/code/generated-state-009-kubernetes-runtime) | `none` | `none` | [008-order-management-matcher](/docs/learning/state-008-order-management-matcher) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-008-order-management-matcher...code%2Fgenerated-state-009-kubernetes-runtime) | `n/a` |
| `010-tilt-kubernetes-dev-loop` | [link](/docs/learning/state-010-tilt-kubernetes-dev-loop) | [link](/specs/tilt-kubernetes-dev-loop) | [code/generated-state-010-tilt-kubernetes-dev-loop](https://github.com/finos/traderX/tree/code/generated-state-010-tilt-kubernetes-dev-loop) | `none` | `none` | [009-kubernetes-runtime](/docs/learning/state-009-kubernetes-runtime) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-009-kubernetes-runtime...code%2Fgenerated-state-010-tilt-kubernetes-dev-loop) | `n/a` |
| `011-platform-convergence-c3` | [link](/docs/learning/state-011-platform-convergence-c3) | [link](/specs/platform-convergence-c3) | [code/generated-state-011-platform-convergence-c3](https://github.com/finos/traderX/tree/code/generated-state-011-platform-convergence-c3) | `C3` | [008-order-management-matcher](/docs/learning/state-008-order-management-matcher) | [010-tilt-kubernetes-dev-loop](/docs/learning/state-010-tilt-kubernetes-dev-loop) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-010-tilt-kubernetes-dev-loop...code%2Fgenerated-state-011-platform-convergence-c3) | [link](/docs/adr/008-convergence-state-model) |
| `012-radius-kubernetes-platform` | [link](/docs/learning/state-012-radius-kubernetes-platform) | [link](/specs/radius-kubernetes-platform) | [code/generated-state-012-radius-kubernetes-platform](https://github.com/finos/traderX/tree/code/generated-state-012-radius-kubernetes-platform) | `none` | `none` | [009-kubernetes-runtime](/docs/learning/state-009-kubernetes-runtime) | [link](https://github.com/finos/traderX/compare/code%2Fgenerated-state-009-kubernetes-runtime...code%2Fgenerated-state-012-radius-kubernetes-platform) | `n/a` |

## How To Use This Section

1. Open a state guide from this catalog.
2. Use the GitHub compare link to inspect exact code changes against previous state(s).
3. Read the plain-English delta for rationale and intent.
4. Follow links back to spec architecture/flows/contracts when you need system context.

## Recommended Starting Points For New State Design

- `003-containerized-compose-runtime` (C0): Containerized Compose Runtime (NGINX Ingress)
- `006-observability-lgtm-compose` (C1): Observability with LGTM on Compose
- `008-order-management-matcher` (C2): Order Management and Matcher
- `011-platform-convergence-c3` (C3): Platform Convergence C3
