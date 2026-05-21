---
title: "State 009: Order Management and Matcher"
---

# State 009 Learning Guide

## Position In Learning Graph

- Previous state(s): [008-pricing-awareness-market-data](/docs/learning/state-008-pricing-awareness-market-data)
- Dotted-line parent(s): none
- Next state(s): [010-kubernetes-runtime](/docs/learning/state-010-kubernetes-runtime)

## Convergence Metadata

- Convergence state: `yes`
- Convergence level: `C2`
- Lineage role: `canonical`
- Nearest previous convergence: [007-observability-lgtm-compose](/docs/learning/state-007-observability-lgtm-compose)
- Nearest next convergence: [012-platform-convergence-c3](/docs/learning/state-012-platform-convergence-c3)

## Rendered Code

- Generated branch: [code/generated-state-009-order-management-matcher](https://github.com/finos/traderX/tree/code/generated-state-009-order-management-matcher)
- Authoring branch (spec source): [main](https://github.com/finos/traderX/tree/main)

## Code Comparison With Previous State

- Compare against `008-pricing-awareness-market-data`: [code/generated-state-008-pricing-awareness-market-data...code/generated-state-009-order-management-matcher](https://github.com/finos/traderX/compare/code%2Fgenerated-state-008-pricing-awareness-market-data...code%2Fgenerated-state-009-order-management-matcher)

## Plain-English Code Delta

- **Added:** Order domain with lifecycle states (`NEW`, `PARTIALLY_FILLED`, `FILLED`, `CANCELED`, `REJECTED`).
- **Added:** Order matcher component (Java Spring Boot) for evaluating executable orders and publishing fill events.
- **Added:** Order management API surface for create/list/cancel/force-fill workflows.
- **Added:** Database-backed order persistence so active orders survive order-matcher restarts.
- **Added:** Tick-driven auto-fill policy for in-the-money orders:
- **Added:** remaining quantity `< 1000`: fill full remaining quantity
- **Added:** remaining quantity `>= 1000`: fill half (rounded up)
- **Added:** Trader UI order ticket for limit-order creation, separated from market-trade ticket workflow.

## Run This State

```bash
./scripts/start-state-009-order-management-matcher-generated.sh
```

## Canonical Spec Links

- State spec pack: [/specs/order-management-matcher](/specs/order-management-matcher)
- Architecture: [/specs/order-management-matcher/system/architecture](/specs/order-management-matcher/system/architecture)
- Flows / topology: [/specs/order-management-matcher/system/runtime-topology](/specs/order-management-matcher/system/runtime-topology)
- Research: [link](/specs/order-management-matcher/research)
- Data model: [link](/specs/order-management-matcher/data-model)
- Quickstart: [link](/specs/order-management-matcher/quickstart)

