---
title: "State 008: Order Management and Matcher"
---

# State 008 Learning Guide

## Position In Learning Graph

- Previous state(s): [007-pricing-awareness-market-data](/docs/learning/state-007-pricing-awareness-market-data)
- Dotted-line parent(s): none
- Next state(s): [009-kubernetes-runtime](/docs/learning/state-009-kubernetes-runtime)

## Convergence Metadata

- Convergence state: `yes`
- Convergence level: `C2`
- Lineage role: `canonical`
- Nearest previous convergence: [006-observability-lgtm-compose](/docs/learning/state-006-observability-lgtm-compose)
- Nearest next convergence: [011-platform-convergence-c3](/docs/learning/state-011-platform-convergence-c3)

## Rendered Code

- Generated branch: [code/generated-state-008-order-management-matcher](https://github.com/finos/traderX/tree/code/generated-state-008-order-management-matcher)
- Authoring branch (spec source): [feature/agentic-renovation](https://github.com/finos/traderX/tree/feature/agentic-renovation)

## Code Comparison With Previous State

- Compare against `007-pricing-awareness-market-data`: [code/generated-state-007-pricing-awareness-market-data...code/generated-state-008-order-management-matcher](https://github.com/finos/traderX/compare/code%2Fgenerated-state-007-pricing-awareness-market-data...code%2Fgenerated-state-008-order-management-matcher)

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
./scripts/start-state-008-order-management-matcher-generated.sh
```

## Canonical Spec Links

- State spec pack: [/specs/order-management-matcher](/specs/order-management-matcher)
- Architecture: [/specs/order-management-matcher/system/architecture](/specs/order-management-matcher/system/architecture)
- Flows / topology: [/specs/order-management-matcher/system/runtime-topology](/specs/order-management-matcher/system/runtime-topology)
- Research: [link](/specs/order-management-matcher/research)
- Data model: [link](/specs/order-management-matcher/data-model)
- Quickstart: [link](/specs/order-management-matcher/quickstart)

