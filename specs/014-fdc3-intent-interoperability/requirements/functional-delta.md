# Functional Delta: 014-fdc3-intent-interoperability

Parent state: `012-platform-convergence-c3`

Document only functional behavior changes introduced by this state.

## Added

- FDC3 interop adapter in TraderX frontend for DesktopAgent integration.
- Outbound `fdc3.instrument` context publishing when a user selects a ticker-bearing row in trade/order/position views.
- Inbound `fdc3.instrument` context handling that updates ticker-focused UI state (filters and ticket defaults).
- Standard intent handling for `ViewOrders` (instrument-scoped orders view routing).
- Outbound standard intent triggers for `ViewChart` and `ViewQuote` from explicit TraderX UI actions.
- Custom inbound intents `TraderX.CreateTradeTicket` and `TraderX.CreateOrderTicket` that open the respective ticket UI with preselected ticker context.
- Local Sail sidecar runtime profile for interop demos.
- Seeded Sail app-directory profile that includes:
  - TraderX app entry (ticket intents + `ViewOrders` handler)
  - at least two additional demo apps for chart/quote or equivalent symbol workflows.
- Canonical two-tab Sail demo profile (`default-client-state.json`):
  - tab `One` for chart/pricing/ticket-launch actions
  - tab `Two` for news workflow.
- Operator demo script requirements captured in feature artifacts and generated README.
- Sail pin manifest (`generation/sail-pin.env`) captured in-spec and propagated into generated state artifacts to default runtime bootstrap to a known-good Sail commit.

## Changed

- Trade/order/position blotter interactions now optionally emit cross-app context events in addition to local UI updates.
- Ticket launch pathways now include an intent-driven path alongside existing in-app button flows.
- Frontend startup includes FDC3 capability detection and listener registration, with graceful degraded behavior when unavailable.
- State runtime startup gains optional/paired Sail lifecycle management separate from TraderX ingress path.
- Sail runtime bootstrap now defaults to a pinned commit SHA from the state pin manifest rather than tracking `main` implicitly.

## Removed

- None.

## Flow Impact

- `F4` (realtime updates): now coexists with cross-app symbol context distribution for selected securities.
- `F6` (order ticket + blotter workflow): extended with intent-driven order ticket launch and symbol prefill.
- New flow `F7`: cross-application symbol synchronization (TraderX selection -> external chart/quote app update).
- New flow `F8`: external app intent -> TraderX ticket launch (`Trade`/`Order`) with ticker preselection.
- New flow `F9`: local demo bootstrap (TraderX + Sail + demo apps) and end-to-end scripted interoperability verification.
