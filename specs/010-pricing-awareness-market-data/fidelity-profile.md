# State 010 Fidelity Profile

This profile captures the required technical shape for state `010-pricing-awareness-market-data`.

## Runtime Stack Deltas From State 007

| Concern | State 007 | State 010 |
| --- | --- | --- |
| Messaging backbone | `nats-broker` | `nats-broker` + `price-publisher` |
| Trade schema | quantity/state only | + execution `price` |
| Position schema | quantity only | + `averageCostBasis` |
| Browser real-time stream | account-scoped trade/position updates | account-scoped updates + `pricing.*` streams |
| Runtime model | Docker Compose | Docker Compose |

## Pricing Constraints

- Persisted `price` and `averageCostBasis` use 3-decimal precision.
- Market data tick generation is synthetic random walk bounded to ±10% around recent open/close baseline.
- Bootstrap mode:
  - `snapshot` for deterministic local behavior,
  - `yfinance` for startup seeding from recent market data.

## Closeness Policy

State `010` is functional-close to `007` with additive pricing behavior.  
Messaging/runtime architecture remains unchanged except for adding the pricing publisher component.
