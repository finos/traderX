# Functional Delta: 010 Pricing Awareness and Market Data

Parent state: `007-messaging-nats-replacement`

## Added

- Trade execution pricing (`trade.price`) with 3-decimal precision.
- Position pre-aggregated volume-weighted average cost basis (`position.averageCostBasis`).
- Market price stream topics (`pricing.<TICKER>`) from a new `price-publisher` component.
- Startup-assigned per-ticker volatility band profile for synthetic pricing bounds (20% @ ±4%, 60% @ ±2%, 20% strict open/close).
- UI valuation fields: market price, position value, unrealized P&L, portfolio totals.
- Position blotter `OPEN` column and directional market marker (`▲/▼/■`) against open price.
- Conditional valuation highlighting in position blotter for market-price/open and value-vs-cost comparisons.
- Trade ticket selected-security live price stream subscription from `pricing.<TICKER>`.
- Shared supported ticker universe configuration across `reference-data` and `price-publisher`.
- Reference-data ticker normalization from `FB` to `META` for this state.
- Price publisher randomized batch cadence: publish every `750-1500ms` (default) for random subset (`25%` default).
- Expanded default sample symbol set includes financial-services institutions used in TraderX demos (`MS`, `UBS`, `C`, `GS`, `DB`, `JPM`, `COF`, `DFS`, `FNMA`, `FIS`, `FNF`).

## Changed

- `trade-service` now enriches submitted trade orders with current price before NATS publication.
- `trade-processor` now computes and persists average cost basis per account/security on every trade.
- Trade blotter now includes execution price and relative execution timestamp rendering.
- Position blotter now updates value and P&L in real time from price stream ticks.
- Position blotter now applies semantic styling and marker cues for quick up/down valuation reading.
- Runtime ticker lists are now intentionally constrained to a shared supported set for consistency across validation, pricing, and UI.

## Removed

- No runtime component removals in this state.

## Flow Impact

- `F2` (trade submission and processing): now includes price lookup and persisted execution price.
- `F4` (real-time blotter updates): now includes market price stream consumption and valuation refresh.
- `F1` (ticket entry + reference data): now includes consistent supported symbols aligned with streaming pricing universe.
