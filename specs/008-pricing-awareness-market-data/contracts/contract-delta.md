# Contract Delta: 010 Pricing Awareness and Market Data

Parent state: `006-messaging-nats-replacement`

## REST/OpenAPI Changes

- `trade-service` request/response schema extends `TradeOrder` with `price`.
- `position-service` payloads include `averageCostBasis` in positions and `price` in trades.
- New local service endpoint:
  - `price-publisher`: `GET /prices`, `GET /prices/{ticker}`, `GET /health`.
  - `GET /prices` is the canonical multi-symbol bootstrap path (all symbols by default, optionally filtered by request parameters when provided by implementation).
  - `price-publisher /health` includes active publish cadence config (`minMs`, `maxMs`, `ratio`).

## Event Contract Changes

- Existing account-scoped topics remain:
  - `/accounts/<accountId>/trades`
  - `/accounts/<accountId>/positions`
- New market data topic family:
  - `pricing.<TICKER>`

Expected pricing payload:

```json
{
  "ticker": "IBM",
  "price": 187.245,
  "openPrice": 186.000,
  "closePrice": 187.400,
  "asOf": "2026-03-31T11:00:00.000Z",
  "source": "snapshot"
}
```

`asOf` is a server-assigned timestamp and is required for both snapshot REST responses and stream (`pricing.<TICKER>`) events so clients can safely pick the freshest update.

## Reference Data Symbol Contract Notes

- State `010` normalizes legacy `FB` symbol to `META` for returned stock identifiers.
- Runtime supported symbol set is expected to match between `reference-data` and `price-publisher`.
