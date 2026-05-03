# Feature Specification: Pricing Awareness and Market Data Streaming

**Feature Branch**: `008-pricing-awareness-market-data`  
**Created**: 2026-03-31  
**Status**: Implemented  
**Input**: Transition delta from `007-observability-lgtm-compose`

## User Stories

- As a trader, I want each executed trade to include its execution price so blotters are economically meaningful.
- As a portfolio user, I want positions to expose average cost basis so unrealized P&L can be computed in real time.
- As a frontend user, I want live market price updates to refresh position value and totals without page refresh.
- As a frontend user, I want an initial snapshot price rendered immediately while stream subscription is still connecting.
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
- FR-1018: State SHALL expose price snapshot REST retrieval for both single ticker and multi-ticker retrieval in one request (for example ticket bootstrap vs. grid bootstrap).
- FR-1019: Ticket and blotter screens that display streaming market price SHALL issue snapshot bootstrap retrieval in parallel with stream subscription and render the freshest price by server timestamp.
- FR-1020: Price payloads delivered via both REST snapshot and `pricing.<TICKER>` stream SHALL include server-assigned event time (`asOf`) so clients can deterministically resolve snapshot-vs-stream race conditions.
- FR-1021: API explorer runtime (`/api/docs`) SHALL expose a companion pub/sub inspector page at `pubsub-inspector.html`.
- FR-1022: Pub/sub inspector SHALL auto-connect to the state message bus websocket route using environment-derived address resolution (no manual endpoint input).
- FR-1023: Pub/sub inspector SHALL start unsubscribed with an empty feed; all subscriptions are user-initiated.
- FR-1024: Pub/sub inspector SHALL render one-click topic buttons generated from cumulative `system/messaging-subject-map.md` for the state.
- FR-1025: Pub/sub inspector SHALL visually distinguish wildcard subjects and parameterized subjects; parameterized buttons SHALL prefill topic input with a placeholder pattern for user substitution.
- FR-1026: Pub/sub inspector SHALL allow arbitrary topic/pattern subscription input and maintain an active-subscription list with per-subscription message counters and unsubscribe controls.
- FR-1027: Pub/sub inspector feed rows SHALL show delivery topic, matched subscription pattern (when different), receipt timestamp, payload preview, and expandable pretty JSON payload.
- FR-1028: Pub/sub inspector in-memory feed buffer SHALL cap at 2000 messages with oldest-first eviction while retaining an uncapped session-total counter.
- FR-1029: Pub/sub inspector SHALL support feed filter, pause/resume display updates, and clear (buffer reset + per-subscription counter reset).
- FR-1030: API explorer index SHALL link to the inspector using a runtime-computed relative URL that resolves correctly under ingress sub-path mounting.
- FR-1031: For states where pub/sub inspector is enabled, main-app `System` menu and About-page `Tools` section SHALL include a Pub/Sub Inspector link bound to generated state metadata (`StateUiMetadata.pubSubInspectorUrl`).
- FR-1032: API explorer and pub/sub inspector pages SHALL include a top-right navigation link back to the TraderX main app web root (`/`).

## Non-Functional Requirements

- NFR-1001: Market price stamping SHALL preserve existing request/response latency characteristics for baseline local runtime.
- NFR-1002: Pricing publisher component SHALL remain lightweight and local-dev friendly.
- NFR-1003: Pricing subjects SHALL remain wildcard-friendly for browser subscribers using NATS WebSocket.
- NFR-1004: Numeric precision for persisted execution price and cost basis SHALL be capped at 3 decimals.
- NFR-1005: Existing `006` functional flows SHALL remain backward-compatible (trade submit, account validation, realtime updates).
- NFR-1006: Pricing stream defaults SHALL reduce local runtime churn versus per-symbol 1-second fanout while preserving timely UI valuation refresh.
- NFR-1007: Pricing visualization semantics (marker + color) SHALL remain deterministic and derived solely from open/market and cost/value comparisons.
- NFR-1008: For all services in this state that expose Prometheus-compatible metrics, Prometheus scraping and provisioned Grafana visualization SHALL be maintained.
- NFR-1009: `asOf` timestamps for snapshots and stream ticks SHALL be server-assigned UTC instants and consistently comparable across payload sources for the same ticker.
- NFR-1010: Pub/sub inspector SHALL be generated as a self-contained static HTML asset in `api-explorer/` with no runtime build step.
- NFR-1011: Pub/sub inspector message bus client dependency SHALL be vendored as a local asset in generated runtime output (no CDN dependency).
- NFR-1012: Generated topic-button data for the inspector SHALL be pipeline-derived from the state's cumulative messaging subject map, not manually curated.
- NFR-1013: Pub/sub inspector UI responsiveness SHALL remain acceptable at sustained 2000-message buffer occupancy.

## Success Criteria

- SC-1001: Runtime includes healthy `price-publisher` and visible `pricing.<TICKER>` stream activity.
- SC-1002: New trades persist with non-null `price`.
- SC-1003: Positions persist with non-null `averageCostBasis`.
- SC-1004: UI reflects streaming valuation updates without requiring manual page refresh.
- SC-1005: Unknown ticker validation still returns `404`.
- SC-1006: Supported ticker list and pricing stream universe stay aligned (no supported symbol missing price stream/quote).
- SC-1007: `FB` is not exposed by reference-data in this state; `META` is exposed and priced.
- SC-1008: Default sample startup includes the defined financial-services symbols and all return quotes from `price-publisher`.
- SC-1009: For each ticker, UI bootstrap + stream handoff keeps the latest (`max(asOf)`) price when snapshot and stream updates arrive near-simultaneously.
- SC-1010: `/api/docs/pubsub-inspector.html` loads successfully from generated runtime and auto-connects to websocket bus route.
- SC-1011: Inspector-generated topic buttons match the state's cumulative `system/messaging-subject-map.md`.
- SC-1012: Inspector feed displays delivery topic plus wildcard subscription context (`pricing.*`-style) where applicable.
- SC-1013: Inspector enforces 2000-message buffer cap with FIFO eviction while session-total counter continues increasing.
- SC-1014: API explorer and pub/sub inspector each expose a working top-right link to TraderX main app web root (`/`), and main-app metadata-driven menus/pages expose inspector link when enabled.
