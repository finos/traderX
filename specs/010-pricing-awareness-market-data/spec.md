# Feature Specification: Pricing Awareness and Market Data Streaming

**Feature Branch**: `010-pricing-awareness-market-data`  
**Created**: 2026-03-31  
**Status**: Implemented  
**Input**: Transition delta from `007-messaging-nats-replacement`

## User Stories

- As a trader, I want each executed trade to include its execution price so blotters are economically meaningful.
- As a portfolio user, I want positions to expose average cost basis so unrealized P&L can be computed in real time.
- As a frontend user, I want live market price updates to refresh position value and totals without page refresh.
- As a maintainer, I want market data bootstrap to support deterministic snapshots and optional startup sync from yfinance.

## Functional Requirements

- FR-1001: Trade execution payloads SHALL include `price` (maximum 3 decimals).
- FR-1002: `trade-service` SHALL fetch current market price and stamp it on the trade order before publishing to NATS.
- FR-1003: `trade-processor` SHALL persist `trade.price` for settled trades.
- FR-1004: Position schema SHALL include pre-aggregated volume-weighted `averageCostBasis` and update it for each processed trade.
- FR-1005: State SHALL add pricing subject strategy using `pricing.<TICKER>` topics.
- FR-1006: State SHALL add a `price-publisher` that emits bounded-random-walk ticks on `pricing.<TICKER>` anchored to each ticker's startup open/close range.
- FR-1006a: At publisher startup, each ticker SHALL be assigned one volatility band profile for the full process lifetime:
  - 20% of tickers: bounds may exceed open/close by up to 4%,
  - 60% of tickers: bounds may exceed open/close by up to 2%,
  - 20% of tickers: bounds remain strictly within open/close.
- FR-1007: `price-publisher` SHALL support startup bootstrap mode:
  - `snapshot` using local seed data,
  - `yfinance` to fetch latest open/close once at startup, then switch to synthetic tick generation.
- FR-1008: Trade blotter SHALL display execution price and relative execution time (`x min ago` for same-day trades).
- FR-1009: Position blotter SHALL display streaming market price, position value, and net P&L based on `averageCostBasis`.
- FR-1010: Main trade screen SHALL display total portfolio value and total portfolio cost basis.
- FR-1011: Position blotter SHALL include `OPEN` price and render market price with directional marker (`▲` above open, `▼` below open, `■` at open).
- FR-1012: Position blotter SHALL apply conditional highlight styling:
  - market price below open: pink background with dark red text,
  - market price above open: green background with dark green text,
  - position value and P&L follow equivalent negative/positive semantics.
- FR-1013: Trade ticket SHALL stream selected security market price in real time using `pricing.<TICKER>`.
- FR-1014: Supported tradable ticker universe SHALL be aligned between `reference-data` and `price-publisher` via shared runtime configuration.
- FR-1015: Legacy symbol `FB` SHALL be normalized to `META` in reference data responses for this state.
- FR-1016: Price publisher SHALL emit pricing updates on randomized cadence (`750-1500ms` default) and publish only a randomized subset per cycle (`25%` default, configurable).
- FR-1017: Default sample universe SHALL include core financial-services institutions used in demonstrations:
  `MS`, `UBS`, `C`, `GS`, `DB`, `JPM`, `COF`, `DFS`, `FNMA`, and at least one Fidelity-related listed symbol (`FIS` and/or `FNF`).

## Non-Functional Requirements

- NFR-1001: Market price stamping SHALL preserve existing request/response latency characteristics for baseline local runtime.
- NFR-1002: Pricing publisher component SHALL remain lightweight and local-dev friendly.
- NFR-1003: Pricing subjects SHALL remain wildcard-friendly for browser subscribers using NATS WebSocket.
- NFR-1004: Numeric precision for persisted execution price and cost basis SHALL be capped at 3 decimals.
- NFR-1005: Existing `007` functional flows SHALL remain backward-compatible (trade submit, account validation, realtime updates).
- NFR-1006: Pricing stream defaults SHALL reduce local runtime churn versus per-symbol 1-second fanout while preserving timely UI valuation refresh.
- NFR-1007: Pricing visualization semantics (marker + color) SHALL remain deterministic and derived solely from open/market and cost/value comparisons.

## Success Criteria

- SC-1001: Runtime includes healthy `price-publisher` and visible `pricing.<TICKER>` stream activity.
- SC-1002: New trades persist with non-null `price`.
- SC-1003: Positions persist with non-null `averageCostBasis`.
- SC-1004: UI reflects streaming valuation updates without requiring manual page refresh.
- SC-1005: Unknown ticker validation still returns `404`.
- SC-1006: Supported ticker list and pricing stream universe stay aligned (no supported symbol missing price stream/quote).
- SC-1007: `FB` is not exposed by reference-data in this state; `META` is exposed and priced.
- SC-1008: Default sample startup includes the defined financial-services symbols and all return quotes from `price-publisher`.
