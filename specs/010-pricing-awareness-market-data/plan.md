# Implementation Plan: 010 Pricing Awareness and Market Data

## Scope

- Transition from `007-messaging-nats-replacement` to `010-pricing-awareness-market-data`.
- Add functional pricing enhancements while preserving runtime/messaging foundations from `007`.
- Keep runtime model on Docker Compose + NGINX ingress.

## Technical Approach

1. Add a new `price-publisher` component:
   - startup bootstrap from snapshot or yfinance,
   - publish NATS `pricing.<TICKER>` ticks on randomized interval (`750-1500ms` default) for random subset (`25%` default),
   - expose REST lookup for current ticker price.
2. Extend trade submission flow:
   - stamp execution price in `trade-service`,
   - persist trade price in `trade-processor`.
3. Extend position aggregation flow:
   - persist volume-weighted average cost basis at each trade update.
4. Extend frontend:
   - trade blotter price + relative execution time,
   - position blotter open/market/value/P&L updates from price stream with directional/semantic highlighting,
   - portfolio total value + total cost basis summary.
5. Extend conformance/smoke:
   - verify quote endpoint, pricing stream, persisted price/cost-basis fields.

## Exit Criteria

- Trade and position schemas include pricing fields with correct precision.
- Price stream is active and consumed by UI.
- End-to-end trade flow remains functional with pricing enrichment.
- State runtime scripts and docs are published for generated branch output.
