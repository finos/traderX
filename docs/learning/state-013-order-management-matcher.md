---
title: "State 013: Order Management and Matcher"
---

# State 013 Learning Guide

## Position In Learning Graph

- Previous state(s): [012-observability-on-pricing](/docs/learning/state-012-observability-on-pricing)
- Next state(s): none

## Rendered Code

- Generated branch: [code/generated-state-013-order-management-matcher](https://github.com/finos/traderX/tree/code/generated-state-013-order-management-matcher)
- Authoring branch (spec source): [feature/agentic-renovation](https://github.com/finos/traderX/tree/feature/agentic-renovation)

## Code Comparison With Previous State

- Compare against `012-observability-on-pricing`: [code/generated-state-012-observability-on-pricing...code/generated-state-013-order-management-matcher](https://github.com/finos/traderX/compare/code%2Fgenerated-state-012-observability-on-pricing...code%2Fgenerated-state-013-order-management-matcher)

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
TBD
```

## Canonical Spec Links

- State spec pack: [/specs/order-management-matcher](/specs/order-management-matcher)
- Architecture: [/specs/order-management-matcher/system/architecture](/specs/order-management-matcher/system/architecture)
- Flows / topology: [/specs/order-management-matcher/system/runtime-topology](/specs/order-management-matcher/system/runtime-topology)
- Research: [link](/specs/order-management-matcher/research)
- Data model: [link](/specs/order-management-matcher/data-model)
- Quickstart: [link](/specs/order-management-matcher/quickstart)

