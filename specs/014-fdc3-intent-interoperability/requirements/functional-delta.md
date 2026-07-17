# Functional Delta: 014-fdc3-intent-interoperability

Parent state: `012-platform-convergence-c3`

Document only functional behavior changes introduced by this state.

## Added

- FDC3 interop adapter in TraderX frontend for DesktopAgent integration.
- Outbound `fdc3.instrument` context publishing when a user selects a ticker-bearing row in trade/order/position views.
- Inbound `fdc3.instrument` context handling that updates ticker-focused UI state (filters and ticket defaults).
- Outbound and inbound `traderx.account` context handling that synchronizes selected account state across TraderX windows.
- Standard intent handling for `ViewOrders` (instrument-scoped orders view routing).
- Outbound standard intent triggers for `ViewChart` and `ViewQuote` from explicit TraderX UI actions.
- Custom inbound intents `TraderX.CreateTradeTicket` and `TraderX.CreateOrderTicket` that open the respective ticket UI with preselected ticker context.
- Local Sail sidecar runtime profile for interop demos.
- TraderX-owned App Directory profile, served through TraderX ingress, that includes:
  - TraderX app entry (ticket intents + `ViewOrders` handler)
  - Mini TraderX app entry for the `/mini-traderx` standalone companion route
  - TraderX Intent Launcher app for raising ticket intents from the current `fdc3.instrument`
- Sail app-directory aggregation profile that includes:
  - the TraderX-owned App Directory source
  - canonical FDC3 toolbox TradingView widget apps and Pricer app
  - FINOS conformance apps from the Sail v3 branch for standards-oriented validation.
- Sail v3 workspace bootstrap can temporarily inject TraderX, Mini TraderX, the TraderX launcher, TradingView, and Pricer into the Sail app directory fixture until Sail exposes stable multi-App Directory startup configuration.
- Sail multi-App Directory target behavior covers both preconfigured sources (for example environment-variable driven demo setup) and GUI-driven source add/remove during a demo session.
- Mini TraderX standalone route that shows selected account, active instrument, current price, live P&L summary, and an instrument-filtered position blotter.
- Operator demo script requirements captured in feature artifacts and generated README.

## Changed

- Trade/order/position blotter interactions now optionally emit cross-app context events in addition to local UI updates.
- Account selection in the main Trade view now optionally emits cross-app `traderx.account` context and responds to inbound account selection.
- Ticket launch pathways now include an intent-driven path alongside existing in-app button flows.
- Frontend startup includes FDC3 capability detection and listener registration, with graceful degraded behavior when unavailable.
- State runtime startup gains optional/paired Sail lifecycle management separate from TraderX ingress path.
- Existing market-data semantics remain required: snapshot bootstrap + streaming continuation with server-time freshness ordering, and push-driven trade/position/order blotter updates after REST bootstrap.

## Removed

- None.

## Flow Impact

- `F4` (realtime updates): now coexists with cross-app symbol context distribution for selected securities.
- `F6` (order ticket + blotter workflow): extended with intent-driven order ticket launch and symbol prefill.
- New flow `F7`: cross-application symbol synchronization (TraderX selection -> external chart/quote app update).
- New flow `F8`: external app intent -> TraderX ticket launch (`Trade`/`Order`) with ticker preselection.
- New flow `F9`: local demo bootstrap (TraderX + Sail + TraderX Intent Launcher + TradingView/Pricer + conformance apps) and end-to-end scripted interoperability verification.
- New flow `F10`: account and instrument synchronization between main TraderX and Mini TraderX through `traderx.account` and `fdc3.instrument`.
- Existing pricing/realtime flow behavior inherited from prior states remains non-regressive under FDC3 enablement.
