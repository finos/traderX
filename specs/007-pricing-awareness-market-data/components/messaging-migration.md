# Component Spec: Pricing Stream Strategy

## Goal

Add market price streams on top of existing NATS messaging without disrupting account-scoped trade/position update topics.

## Subject Strategy

- `pricing.<TICKER>` for per-security market ticks.
- Existing account subjects remain:
  - `/accounts/<accountId>/trades`
  - `/accounts/<accountId>/positions`

## Producer and Consumers

- Producer: `price-publisher`
- Consumers:
  - Angular frontend valuation layer (market price + P&L updates)
  - Optional backend consumers in future states
