# Data Model: FDC3 Intent Interoperability on C3

## Scope

State `014` introduces frontend interoperability data shapes. No persistent database schema changes are required.

## Entity Changes

### Added (frontend/domain models)

- `Fdc3InstrumentContext`
  - Source of truth for outbound/inbound symbol context.
  - Required fields: `type`, `id.ticker`.
  - Optional fields: `id.ISIN`, `id.FIGI`, `id.RIC`, `name`.
- `InteropCapabilityState`
  - Tracks whether DesktopAgent is available and which intents/features are enabled.
- `TicketLaunchIntentPayload`
  - Normalized payload model for custom ticket-launch intents.

### Changed

- Trade/order/position view models gain mapping to/from `Fdc3InstrumentContext` through shared utility methods.

### Removed

- None.

## Persistence Impact

- No SQL/table/entity persistence changes.
- No migration scripts required.

## Compatibility Notes

- Existing API payloads remain unchanged.
- Interop models are additive and local to frontend orchestration.
