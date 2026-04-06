---
title: "March 31, 2026: State 007 - Pricing Awareness as a Functional Track"
slug: /blog/2026-03-31-state-010-pricing-awareness-functional-track
---

# State 007: Pricing Awareness as a Functional Track

State `007-pricing-awareness-market-data` extends `006-observability-lgtm-compose` and marks the first major functional expansion after the NATS messaging upgrade.

This state adds pricing awareness to trade execution, persistence, and portfolio presentation, while preserving the existing end-to-end trading flow.

## Why This State

The system previously handled quantities and securities but had no execution pricing context in persisted trades or aggregated positions.  
State `007` introduces that missing functional layer and keeps it realtime via NATS topics.

## What Changed

- Added a new `price-publisher` component that emits random-walk quotes per ticker on `pricing.<TICKER>`.
- Stamped execution price on trade submission in `trade-service`.
- Persisted price on trades and volume-weighted average cost basis on positions in `trade-processor`.
- Extended schema to include `TRADES.Price` and `POSITIONS.AverageCostBasis`.
- Updated Angular blotters to show trade price, relative execution time, position value, cost basis, and net P&L totals.

## Verification and Regression Coverage

- State-specific smoke suite: `./scripts/test-state-007-pricing-awareness-market-data.sh`
- Realtime checks validated:
  - account trade stream
  - account position stream
  - pricing stream (`pricing.IBM`)
- Persistence checks validated:
  - `trade.price` is populated
  - `position.averageCostBasis` is populated
- Baseline overlay smoke tests also pass under the state runtime to ensure no regressions in prior behavior.

## Spec + Code Links

- State spec pack: [/specs/pricing-awareness-market-data](/specs/pricing-awareness-market-data)
- Learning guide: [/docs/learning/state-007-pricing-awareness-market-data](/docs/learning/state-007-pricing-awareness-market-data)
- Generated code branch: [code/generated-state-007-pricing-awareness-market-data](https://github.com/finos/traderX/tree/code/generated-state-007-pricing-awareness-market-data)
- Compare vs parent (`006`): [code/generated-state-006-observability-lgtm-compose...code/generated-state-007-pricing-awareness-market-data](https://github.com/finos/traderX/compare/code%2Fgenerated-state-006-observability-lgtm-compose...code%2Fgenerated-state-007-pricing-awareness-market-data)
