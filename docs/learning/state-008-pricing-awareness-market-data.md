---
title: "State 008: Pricing Awareness and Market Data Streaming"
---

# State 008 Learning Guide

## Position In Learning Graph

- Previous state(s): [007-observability-lgtm-compose](/docs/learning/state-007-observability-lgtm-compose)
- Dotted-line parent(s): none
- Next state(s): [009-order-management-matcher](/docs/learning/state-009-order-management-matcher)

## Convergence Metadata

- Convergence state: `no`
- Convergence level: `none`
- Lineage role: `canonical`
- Nearest previous convergence: `none`
- Nearest next convergence: `none`

## Rendered Code

- Generated branch: [code/generated-state-008-pricing-awareness-market-data](https://github.com/finos/traderX/tree/code/generated-state-008-pricing-awareness-market-data)
- Authoring branch (spec source): [main](https://github.com/finos/traderX/tree/main)

## Code Comparison With Previous State

- Compare against `007-observability-lgtm-compose`: [code/generated-state-007-observability-lgtm-compose...code/generated-state-008-pricing-awareness-market-data](https://github.com/finos/traderX/compare/code%2Fgenerated-state-007-observability-lgtm-compose...code%2Fgenerated-state-008-pricing-awareness-market-data)

## Plain-English Code Delta

- **Added:** Trade execution pricing (`trade.price`) with 3-decimal precision.
- **Added:** Position pre-aggregated volume-weighted average cost basis (`position.averageCostBasis`).
- **Added:** Market price stream topics (`pricing.<TICKER>`) from a new `price-publisher` component.
- **Added:** Startup-assigned per-ticker volatility band profile for synthetic pricing bounds (20% @ ±4%, 60% @ ±2%, 20% strict open/close).
- **Added:** UI valuation fields: market price, position value, unrealized P&L, portfolio totals.
- **Added:** Position blotter `OPEN` column and directional market marker (`▲/▼/■`) against open price.
- **Added:** Conditional valuation highlighting in position blotter for market-price/open and value-vs-cost comparisons.
- **Added:** Trade ticket selected-security live price stream subscription from `pricing.<TICKER>`.

## Run This State

```bash
./scripts/start-state-008-pricing-awareness-market-data-generated.sh
```

## Canonical Spec Links

- State spec pack: [/specs/pricing-awareness-market-data](/specs/pricing-awareness-market-data)
- Architecture: [/specs/pricing-awareness-market-data/system/architecture](/specs/pricing-awareness-market-data/system/architecture)
- Flows / topology: [/specs/pricing-awareness-market-data/system/runtime-topology](/specs/pricing-awareness-market-data/system/runtime-topology)
- Research: [link](/specs/pricing-awareness-market-data/research)
- Data model: [link](/specs/pricing-awareness-market-data/data-model)
- Quickstart: [link](/specs/pricing-awareness-market-data/quickstart)

