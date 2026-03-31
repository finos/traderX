# Price Publisher (State 010)

Publishes synthetic market prices to NATS subjects (`pricing.<TICKER>`) and exposes REST quote endpoints used by trade-service.

## Endpoints

- `GET /health`
- `GET /prices`
- `GET /prices/:ticker`

## Bootstrap Modes

- `PRICE_BOOTSTRAP_MODE=snapshot` (default)
- `PRICE_BOOTSTRAP_MODE=yfinance` (fetches previous market open/close once at startup, then uses synthetic walk)

## Volatility Band Assignment

At startup, each ticker is assigned one synthetic volatility band profile for the lifetime of the process:

- 20% of tickers: may move up to ±4% beyond startup open/close bounds
- 60% of tickers: may move up to ±2% beyond startup open/close bounds
- 20% of tickers: constrained strictly between startup open/close bounds

## NATS Subjects

- `pricing.AAPL`
- `pricing.MSFT`
- `pricing.<TICKER>`

## Universe Alignment

- `PRICE_TICKERS` controls which symbols are bootstrapped at startup.
- In state `010` compose, this is wired to shared `SUPPORTED_TICKERS`.
- `reference-data` uses the same shared list via `REFERENCE_DATA_SUPPORTED_TICKERS`, so every supported symbol has a corresponding price stream and quote endpoint.
