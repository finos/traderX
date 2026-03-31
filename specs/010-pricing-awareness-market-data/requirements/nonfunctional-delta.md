# Non-Functional Delta: 010 Pricing Awareness and Market Data

Parent state: `007-messaging-nats-replacement`

## Runtime / Operations

- Add `price-publisher` service to compose runtime with deterministic startup behavior.
- Preserve single ingress model and NATS websocket entrypoint from state `007`.
- Keep market bootstrap mode configurable (`snapshot` or `yfinance`) without code change.
- Keep publish cadence and batch ratio configurable via runtime environment:
  - `PRICE_PUBLISH_INTERVAL_MIN_MS`,
  - `PRICE_PUBLISH_INTERVAL_MAX_MS`,
  - `PRICE_PUBLISH_BATCH_RATIO`.
- Keep supported symbol universe configurable and shared across pricing + reference-data:
  - `SUPPORTED_TICKERS`,
  - `REFERENCE_DATA_SUPPORTED_TICKERS` (wired from shared set in compose).

## Precision / Data Quality

- Persisted trade execution price and position average cost basis use precision scale of 3.
- Position valuation calculations in UI use numeric safety defaults when market prices are temporarily unavailable.

## Performance / Scalability

- Price stream fan-out uses NATS subject wildcard (`pricing.*`) for efficient browser subscription.
- Price generation cadence uses randomized interval (default `750-1500ms`) with subset publish model (default `25%` symbols each cycle) to reduce local message flood.

## Reliability

- yfinance bootstrap is startup-only and falls back to snapshot/fallback values on failure.
- Existing baseline trade/account validation behavior remains unchanged.
- Legacy ticker compatibility is normalized at source (`FB` emitted as `META`) to avoid dual-symbol drift across clients.
