# Migration Guidance: 007 to 010 Pricing Awareness

## Goal

Add pricing behavior on top of state `007` messaging/runtime without breaking existing baseline trade/account workflows.

## Backend Service Changes

### trade-service

- Fetch current price from `price-publisher` (`GET /prices/{ticker}`).
- Stamp `tradeOrder.price` before publishing on `/trades`.

### trade-processor

- Persist `trade.price`.
- Update and persist `position.averageCostBasis` during position aggregation.
- Continue publishing account-scoped events with enriched payloads.

### position-service

- Expose enriched persisted trade/position fields through existing REST endpoints.

### price-publisher (new)

- Bootstrap baseline open/close values from:
  - snapshot file (default), or
  - yfinance (startup-only mode).
- Emit `pricing.<TICKER>` NATS updates every 1-2 seconds.

## Frontend Changes

- Keep account-scoped subscriptions from `007`.
- Add `pricing.*` subscription to update market valuation fields in real time.
- Display:
  - trade execution `price`,
  - relative execution time,
  - position `marketPrice`, value, and P&L,
  - portfolio totals for value and cost basis.

## Cutover Strategy

1. Add `price-publisher` runtime and pricing subject map.
2. Enrich trade submission + persistence with execution price.
3. Enrich position persistence with average cost basis.
4. Extend frontend valuation rendering and totals.

## Post-Migration

- Validate baseline flows F2/F4 still pass with pricing additions.
- Keep advanced pricing engines and risk analytics out of scope for this state.
