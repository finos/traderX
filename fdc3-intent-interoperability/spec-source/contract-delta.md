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

## Shared Selection and Local Filter Contract

- Instrument selection is replayable application state; it is separate from each component instance's `filterOnSelectedTicker` boolean, initially false. The effective filter is the latest valid ticker only when that boolean is true.
- Require `type: "fdc3.instrument"` and a non-empty string `id.ticker`; use the existing normalizer (trim, uppercase, remove exchange prefix/whitespace). Wrong/missing type, missing/empty ticker and non-string values are ignored and do not corrupt the last valid selection.
- There is no instrument-clear message in this state. An empty retained channel context or an empty instrument payload means no new selection, not a command to erase a valid selection. Before the first valid selection, opted-in grids show all tickers with an explanation.
- `ViewOrders` selects the orders view and retains the supplied instrument, but never changes the local filter preference. Ticket intents continue to prefill instruments.
- Account context is `{"type":"fdc3.account","id":{"accountId":"123"}}`. Accept only non-negative safe integer strings, and select only accounts available to the receiving page; `"0"` is TraderX's All Accounts sentinel. Receiving account context never rebroadcasts it. Unknown accounts leave the current scope unchanged.
- Account and instrument contexts are retained separately by type. Local ticker mode never travels on an FDC3 channel. No proprietary container or corporate event-bus dependency is introduced.
- Live order events continue over `OrderAdminService.subscribe`, backed by the configured trade feed, independently of FDC3. Open-order snapshots are merged with events received during the request; terminal events act as tombstones. Reconnect refreshes REST snapshots without changing local mode.

Compatibility: previous documentation described automatic instrument-scoped `ViewOrders`; consumers must now explicitly opt a blotter in. Earlier state generators are unchanged.
