# Trade Order API Contract

## Scope

Canonical Level 4 contract for trade submission and retrieval.

## Endpoints

### `POST /api/v1/trades`

Request:

```json
{
  "accountId": "A-1001",
  "symbol": "AAPL",
  "side": "BUY",
  "quantity": 10
}
```

Response:

```json
{
  "tradeId": "T-12345",
  "state": "BOOKED",
  "bookedAt": "2026-03-27T09:00:00Z"
}
```

Validation:

- `accountId` non-empty
- `symbol` uppercase ticker
- `side` in `BUY|SELL`
- `quantity` integer > 0

### `GET /api/v1/trades/{tradeId}`

Response:

```json
{
  "tradeId": "T-12345",
  "accountId": "A-1001",
  "symbol": "AAPL",
  "side": "BUY",
  "quantity": 10,
  "state": "BOOKED"
}
```

## Drift Rule

Changes to request/response fields require:

- contract update in this file
- Level 4 contract test update under `states/04-contract-driven/contract-tests`
