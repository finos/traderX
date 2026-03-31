# Non-Functional Delta: 010 Pricing Awareness and Market Data

Parent state: `007-messaging-nats-replacement`

## Runtime / Operations

- Add `price-publisher` service to compose runtime with deterministic startup behavior.
- Preserve single ingress model and NATS websocket entrypoint from state `007`.
- Keep market bootstrap mode configurable (`snapshot` or `yfinance`) without code change.

## Precision / Data Quality

- Persisted trade execution price and position average cost basis use precision scale of 3.
- Position valuation calculations in UI use numeric safety defaults when market prices are temporarily unavailable.

## Performance / Scalability

- Price stream fan-out uses NATS subject wildcard (`pricing.*`) for efficient browser subscription.
- Price generation cadence targets 1-2 seconds per ticker in local runtime.

## Reliability

- yfinance bootstrap is startup-only and falls back to snapshot/fallback values on failure.
- Existing baseline trade/account validation behavior remains unchanged.
