# Price Publisher (State 010)

Publishes synthetic market prices to NATS subjects (`pricing.<TICKER>`) and exposes REST quote endpoints used by trade-service.

## Endpoints

- `GET /health`
- `GET /prices`
- `GET /prices/:ticker`

## Bootstrap Modes

- `PRICE_BOOTSTRAP_MODE=snapshot` (default)
- `PRICE_BOOTSTRAP_MODE=yfinance` (fetches previous market open/close once at startup, then uses synthetic walk)

## NATS Subjects

- `pricing.AAPL`
- `pricing.MSFT`
- `pricing.<TICKER>`
