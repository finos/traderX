---
title: "State 010: Pricing Awareness and Market Data Streaming"
---

# State 010 Learning Guide

## Position In Learning Graph

- Previous state(s): [007-messaging-nats-replacement](/docs/learning/state-007-messaging-nats-replacement)
- Next state(s): none

## Rendered Code

- Generated branch: [code/generated-state-010-pricing-awareness-market-data](https://github.com/finos/traderX/tree/code/generated-state-010-pricing-awareness-market-data)
- Authoring branch (spec source): [feature/agentic-renovation](https://github.com/finos/traderX/tree/feature/agentic-renovation)

## Code Comparison With Previous State

- Compare against `007-messaging-nats-replacement`: [code/generated-state-007-messaging-nats-replacement...code/generated-state-010-pricing-awareness-market-data](https://github.com/finos/traderX/compare/code%2Fgenerated-state-007-messaging-nats-replacement...code%2Fgenerated-state-010-pricing-awareness-market-data)

## Plain-English Code Delta

- **Added:** Trade execution pricing (`trade.price`) with 3-decimal precision.
- **Added:** Position pre-aggregated volume-weighted average cost basis (`position.averageCostBasis`).
- **Added:** Market price stream topics (`pricing.<TICKER>`) from a new `price-publisher` component.
- **Added:** UI valuation fields: market price, position value, unrealized P&L, portfolio totals.
- **Changed:** `trade-service` now enriches submitted trade orders with current price before NATS publication.
- **Changed:** `trade-processor` now computes and persists average cost basis per account/security on every trade.
- **Changed:** Trade blotter now includes execution price and relative execution timestamp rendering.
- **Changed:** Position blotter now updates value and P&L in real time from price stream ticks.

## Run This State

```bash
./scripts/start-state-010-pricing-awareness-market-data-generated.sh
```

## Canonical Spec Links

- State spec pack: [/specs/pricing-awareness-market-data](/specs/pricing-awareness-market-data)
- Architecture: [/specs/pricing-awareness-market-data/system/architecture](/specs/pricing-awareness-market-data/system/architecture)
- Flows / topology: [/specs/pricing-awareness-market-data/system/runtime-topology](/specs/pricing-awareness-market-data/system/runtime-topology)

