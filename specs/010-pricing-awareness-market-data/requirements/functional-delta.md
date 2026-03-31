# Functional Delta: 010 Pricing Awareness and Market Data

Parent state: `007-messaging-nats-replacement`

## Added

- Trade execution pricing (`trade.price`) with 3-decimal precision.
- Position pre-aggregated volume-weighted average cost basis (`position.averageCostBasis`).
- Market price stream topics (`pricing.<TICKER>`) from a new `price-publisher` component.
- UI valuation fields: market price, position value, unrealized P&L, portfolio totals.

## Changed

- `trade-service` now enriches submitted trade orders with current price before NATS publication.
- `trade-processor` now computes and persists average cost basis per account/security on every trade.
- Trade blotter now includes execution price and relative execution timestamp rendering.
- Position blotter now updates value and P&L in real time from price stream ticks.

## Removed

- No runtime component removals in this state.

## Flow Impact

- `F2` (trade submission and processing): now includes price lookup and persisted execution price.
- `F4` (real-time blotter updates): now includes market price stream consumption and valuation refresh.
