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
- Market data tick generation is synthetic random walk bounded by startup open/close with per-ticker startup-assigned band profile:
  - 20% of tickers: up to ±4% beyond open/close,
  - 60% of tickers: up to ±2% beyond open/close,
  - 20% of tickers: strict open/close bounds.
- Bootstrap mode:
  - `snapshot` for deterministic local behavior,
  - `yfinance` for startup seeding from recent market data.
- Publish model:
  - randomized interval defaults to `750-1500ms`,
  - each cycle publishes a randomized subset (default `25%`) of symbols,
  - all parameters are runtime-configurable.
- Symbol universe:
  - reference-data and price-publisher are configured to share the same supported symbol list,
  - legacy `FB` is normalized to `META` in reference-data outputs.

## UI Fidelity Constraints

- Position blotter includes `OPEN`, `MKT PRICE`, `POSITION VALUE`, and `P&L`.
- Market price row semantics are computed against open price:
  - above open: `▲` + green highlight,
  - below open: `▼` + pink highlight,
  - equal open: neutral marker.
- Position value and P&L use green/pink highlight semantics for positive/negative valuation state.

## Closeness Policy

State `010` is functional-close to `007` with additive pricing behavior.  
Messaging/runtime architecture remains unchanged except for adding the pricing publisher component.
