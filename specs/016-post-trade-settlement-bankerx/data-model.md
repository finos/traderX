# Data Model: FDC3 Post-Trade DvP Settlement (TraderX ↔ BankerX)

## Scope

State `016` introduces post-trade settlement data shapes in the TraderX frontend. No persistent database schema changes are required.

## Entity Changes

### Added (frontend/domain models)

- `Fdc3PaymentContext`
  - The canonical outbound settlement context (`type: "fdc3.paymentContext"`).
  - Required fields: `type`, `amount`, `currency`, `pair`, `rate`, `debtor`, `creditor`, `networkRouting.uetr`.
  - Optional fields: `networkRouting.route` (`Trilateral Powerhouse` | `Solana Token-2022` | `XRPL Altnet`), memo metadata.
- `SettlementInstruction`
  - Normalized payload model built from a confirmed blotter row + settlement accounts, consumed by the payment-context builder.
- `SettlementStatusRecord`
  - Inbound pacs.002-derived record: `uetr`, `status` (`Acsc` | rejection), `settlementRail`, `receiptHashes`.
- `BankerXDispatchState`
  - Per-row dispatch tracking: `uetr`, dispatch mode (`fdc3` | `direct-web`), resolution app id, timestamp.

### Changed

- Trade Blotter row view models gain a `settlementState` attribute (`NONE` → `DISPATCHED` → `SETTLED`) plus the `SETTLE (BANKERX)` action binding.

### Removed

- None.

## Persistence Impact

- No SQL/table/entity persistence changes; settlement correlation is session-scoped (UETR-keyed).
- No migration scripts required.

## Compatibility Notes

- Existing API payloads remain unchanged.
- Settlement models are additive and local to frontend orchestration.
- Rows without settlement state render exactly as in state `014`.