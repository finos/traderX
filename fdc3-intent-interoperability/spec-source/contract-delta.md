# Contract Delta: 014-fdc3-intent-interoperability

Parent state: `012-platform-convergence-c3`

Document any API/event/schema changes for this state.

## OpenAPI Changes

- No backend OpenAPI changes are required for this state.

## Event Contract Changes

- Existing NATS event contracts remain unchanged.
- FDC3 interoperability introduces application-level context/intent contracts handled in-browser.

## Interop Contract Changes (App-Level)

### Supported Context Types

- Inbound: `fdc3.instrument`
- Outbound: `fdc3.instrument`

### Inbound Intents (TraderX Listens For)

- `ViewOrders` with `fdc3.instrument`
- `TraderX.CreateTradeTicket` with `fdc3.instrument`
- `TraderX.CreateOrderTicket` with `fdc3.instrument`

### Outbound Intents (TraderX Raises)

- `ViewChart` with `fdc3.instrument`
- `ViewQuote` with `fdc3.instrument`

### Context Mapping Rules

- Canonical symbol source: TraderX security/ticker fields (`security`, `ticker`) normalized to uppercase.
- Minimum context payload requirement:
  - `type = "fdc3.instrument"`
  - `id.ticker` present and non-empty.
- Optional identifiers may be included when available:
  - `id.ISIN`
  - `id.FIGI`
  - `id.RIC`

## App Directory Contract (Sail Demo Profile)

- Seeded TraderX app record includes:
  - launch URL for TraderX runtime entrypoint
  - declared intents under interop metadata (`listensFor` for `ViewOrders`, `TraderX.CreateTradeTicket`, `TraderX.CreateOrderTicket`)
  - declared context support for `fdc3.instrument`
- Demo profile includes additional apps able to consume `fdc3.instrument` and/or raise ticket-launch intents.
- App-directory assets are versioned inside state `014` generated artifacts to avoid manual demo-time editing.

## Compatibility Notes

- Core backend contracts remain backward compatible with state `012`.
- Interop behavior is additive; if FDC3 is unavailable, all pre-existing workflows remain operational.
- Unknown or malformed intent/context payloads are ignored with diagnostics rather than causing user-visible failures.
