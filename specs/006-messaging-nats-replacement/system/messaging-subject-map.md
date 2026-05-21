# Messaging Subject Map (State 006)

## Subject Families

- `trades.new`
  - producer: `trade-service`
  - consumer: `trade-processor`
  - delivery: `point-to-point`
  - wildcard: `no`
  - scope: `global`
  - payload: submitted trade intent (`accountId`, `security`, `quantity`, `side`, `state`)

- `trades.processed`
  - producer: `trade-processor`
  - consumers: monitoring/debug subscribers, optional frontend summary stream
  - delivery: `broadcast`
  - wildcard: `no`
  - scope: `global`
  - payload: processed trade lifecycle event

- `trades.account.<accountId>.updated`
  - producer: `trade-processor`
  - consumer: frontend account-scoped stream
  - delivery: `broadcast`
  - wildcard: `no`
  - scope: `per-account`
  - payload: account trade update

- `positions.account.<accountId>.updated`
  - producer: `trade-processor`
  - consumer: frontend account-scoped stream
  - delivery: `broadcast`
  - wildcard: `no`
  - scope: `per-account`
  - payload: account position delta/update

## Wildcard Subscription Patterns

- Frontend account stream may subscribe to:
  - `trades.account.<accountId>.*`
  - `positions.account.<accountId>.*`
