# Data Model: Order Management and Matcher

## Scope

This state defines data model impact relative to `008-pricing-awareness-market-data`.

## Entity Changes

- Added: `Order` entity persisted in shared runtime database (`OrderBook` table).
  - `orderId` (string/uuid, primary key)
  - `accountId` (int)
  - `security` (string ticker)
  - `side` (`Buy`/`Sell`)
  - `quantity` (int)
  - `remainingQuantity` (int)
  - `limitPrice` (decimal(18,3))
  - `status` (`NEW|PARTIALLY_FILLED|FILLED|CANCELED|REJECTED`)
  - `createdAt` (timestamp)
  - `updatedAt` (timestamp)
  - `lastExecutionPrice` (decimal(18,3), nullable)
  - `lastFillQuantity` (int, nullable)
- Added: in-memory matcher telemetry counters (exported via `/metrics`) for lifecycle and auto-fill behavior.
- Changed: none in existing trade/position schema required by this state (fills remain integrated through current trade/position flow).
- Removed: none.

## Compatibility Notes

- Backward compatibility requirements should be reflected in:
  - `requirements/functional-delta.md`
  - `requirements/nonfunctional-delta.md`
  - `contracts/contract-delta.md`
- Open order count semantics:
  - `open` means status in `NEW|PARTIALLY_FILLED`.
  - `unfilled` means order has `remainingQuantity > 0`.
  - These semantics drive required metrics and dashboard interpretation.
- Auto-fill policy semantics:
  - `Buy` order is in-the-money when `marketPrice <= limitPrice`.
  - `Sell` order is in-the-money when `marketPrice >= limitPrice`.
  - remaining `< 1000`: full fill, otherwise half fill (rounded up), on each matcher tick.

## Traceability

- Data shape links to FR-01301..FR-01304 and NFR-01302..NFR-01304 in `spec.md`.
