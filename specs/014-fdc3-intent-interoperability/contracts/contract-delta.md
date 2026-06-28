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
- Inbound: `traderx.account`
- Outbound: `traderx.account`

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

### TraderX Account Context

`traderx.account` is a state-014 demo context type for synchronizing account selection between TraderX windows.

Minimum payload:

```json
{
  "type": "traderx.account",
  "id": {
    "accountId": "12345"
  },
  "name": "Display Account Name"
}
```

Rules:

- `id.accountId` is required, string-encoded, and maps to the TraderX account id.
- `name` is optional display text for UI affordances only.
- Payloads must not include balances, positions, P&L, or other account-sensitive data.
- Unknown account ids are ignored until the local account list is available; malformed ids are ignored with diagnostics.

## App Directory Contract

TraderX publishes a TraderX-owned FDC3 App Directory source for TraderX-hosted apps. The endpoint uses the FDC3 App Directory REST contract (`/v2/apps`) while the app records and launch metadata target the FDC3 v3 demo runtime.

- TraderX app record includes:
  - launch URL for TraderX runtime entrypoint
  - declared intents under interop metadata (`listensFor` for `ViewOrders`, `TraderX.CreateTradeTicket`, `TraderX.CreateOrderTicket`)
  - declared context support for `fdc3.instrument` and `traderx.account`
- Mini TraderX app record includes launch URL `/mini-traderx` and user channel support for `fdc3.instrument` plus `traderx.account`.
- TraderX Intent Launcher is treated as a TraderX-offered app and belongs in the TraderX-owned App Directory source.
- Demo aggregation includes TraderX-owned apps, frameable TradingView widget apps on port `4023`, a Pricer app on port `4020`, and FINOS conformance apps from the Sail v3 branch.
- Sail should consume multiple App Directory sources through preconfigured startup configuration and a runtime GUI for adding/removing sources.
- Legacy local demo records whose backing ports are not started by this state are excluded from the live directory.
- Until Sail exposes stable multi-directory support, state `014` may version equivalent Sail fixture assets to avoid manual demo-time editing.

Candidate TraderX-owned demo apps for follow-on consideration:

- TraderX Streaming Price Widget: a compact FDC3 app that follows `fdc3.instrument`, displays the current simulated TraderX price stream, and clearly labels prices as dummy simulator data.
- TraderX Account Watch: a compact context-only app that follows `traderx.account` and shows non-sensitive account identity/status metadata without positions or balances.
- TraderX Activity Tape: a read-only workflow app that follows the current instrument and shows recent simulated orders/trades for that ticker.

## Compatibility Notes

- Core backend contracts remain backward compatible with state `012`.
- Interop behavior is additive; if FDC3 is unavailable, all pre-existing workflows remain operational.
- Unknown or malformed intent/context payloads are ignored with diagnostics rather than causing user-visible failures.
