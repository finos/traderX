# Messaging Subject Map (State 007)

## Purpose

Define canonical NATS subject naming for replacing Socket.IO topic usage.

## Subject Families

- `trades.new`
  - producer: `trade-service`
  - consumer: `trade-processor`
  - payload: submitted trade intent

- `trades.processed`
  - producer: `trade-processor`
  - consumers: monitoring/debug subscribers, optional frontend summary stream
  - payload: processed trade lifecycle event

- `trades.account.<accountId>.updated`
  - producer: `trade-processor`
  - consumer: frontend account-scoped stream
  - payload: trade updates scoped to account

- `positions.account.<accountId>.updated`
  - producer: `trade-processor`
  - consumer: frontend account-scoped stream
  - payload: position deltas scoped to account

## Wildcard Usage

- Frontend account stream can subscribe to:
  - `trades.account.<accountId>.*`
  - `positions.account.<accountId>.*`

## Contract Policy

- Keep event payload semantics equivalent to prior state where possible.
- Any schema drift must be captured in `contracts/contract-delta.md` and conformance tests.
