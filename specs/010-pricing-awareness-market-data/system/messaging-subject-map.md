# Messaging Subject Map (State 010)

## Subject Families

- `/trades`
  - producer: `trade-service`
  - consumer: `trade-processor`
  - payload: validated trade order with stamped execution price

- `/accounts/<accountId>/trades`
  - producer: `trade-processor`
  - consumer: frontend trade blotter stream
  - payload: processed trade (includes `price`)

- `/accounts/<accountId>/positions`
  - producer: `trade-processor`
  - consumer: frontend position blotter stream
  - payload: position snapshot (includes `averageCostBasis`)

- `pricing.<TICKER>`
  - producer: `price-publisher`
  - consumer: frontend valuation stream
  - payload: market tick (`price`, `openPrice`, `closePrice`, `asOf`, `source`)

## Wildcard Usage

- Frontend pricing stream subscribes to `pricing.*`.
