# Feature Specification: FDC3 Intent Interoperability on C3

**Feature Branch**: `014-fdc3-intent-interoperability`  
**Created**: 2026-04-16  
**Status**: Planned  
**Input**: Transition delta from `012-platform-convergence-c3`

## User Stories

- As a trader, I want selecting rows in TraderX blotters to update external chart/quote apps automatically.
- As an app integrator, I want other desktop apps to launch TraderX tickets with a preselected ticker via intents.
- As a maintainer, I want TraderX behavior to remain unchanged when no FDC3 desktop agent is available.
- As a demo operator, I want one local command path that launches TraderX plus Sail plus demo apps for a repeatable interop demo.
- As a QA engineer, I want deterministic tests that prove TraderX FDC3 behaviors against both mocks and a local Sail environment.
- As a trader, I want a compact TraderX companion window that follows my selected account and selected instrument while preserving live position valuation.

## Functional Requirements

- FR-01401: TraderX publishes `fdc3.instrument` context when a user selects a trade/order/position row with a ticker symbol.
- FR-01402: TraderX consumes inbound `fdc3.instrument` context and updates UI state by applying ticker-aware filtering to relevant blotters and views.
- FR-01403: TraderX handles standard intent `ViewOrders` for `fdc3.instrument` context by opening the orders view scoped to the provided ticker.
- FR-01404: TraderX raises standard intents `ViewChart` and `ViewQuote` for selected ticker context from explicit UI actions.
- FR-01405: TraderX handles custom intents `TraderX.CreateTradeTicket` and `TraderX.CreateOrderTicket` with `fdc3.instrument` context and opens the corresponding ticket with ticker prefilled.
- FR-01406: Intent-driven ticket launch must preserve existing ticket validation and account-selection rules.
- FR-01407: If FDC3 is not available, TraderX must keep existing non-FDC3 behavior and hide/disable FDC3-only affordances without runtime errors.
- FR-01408: Intent/context mapping logic must use one canonical ticker-normalization path shared by trade, order, and position views.
- FR-01409: State runtime tooling must support launching Sail locally as a sidecar service alongside TraderX C3 runtime.
- FR-01410: TraderX must own and publish App Directory records for TraderX-hosted FDC3 apps, including core TraderX, Mini TraderX, and TraderX Intent Launcher, with declared inbound intent handlers (`ViewOrders`, `TraderX.CreateTradeTicket`, `TraderX.CreateOrderTicket`) and supported context (`fdc3.instrument`, `traderx.account` where applicable).
- FR-01411: Sail sidecar must include only app-directory entries that are actually reachable in the state runtime, sourced from configured app-directory providers where possible: TraderX-hosted apps, canonical FDC3 toolbox TradingView/Pricer demo apps, and FINOS conformance apps. Legacy local sample app records must not be advertised unless their backing ports are also started.
- FR-01412: Sail sidecar must remain externally reachable directly (for example `http://localhost:8090`) and MUST NOT be routed through TraderX ingress.
- FR-01413: The target Sail v3 bootstrap model for this feature is multi-App Directory consumption. Until Sail exposes stable multi-directory configuration, the generated state may inject equivalent app records into Sail startup as a compatibility bridge.
- FR-01414: The feature pack and generated state README must include an explicit operator demo script with ordered steps and expected outcomes for the Sail v3 workspace.
- FR-01415: FDC3 integration must not regress inherited realtime market-data behavior: price-aware views continue to use snapshot bootstrap + stream updates with server-time freshness ordering, and trade/position/order blotters remain push-driven after REST bootstrap.
- FR-01416: The state-specific header override in this feature SHALL retain the inherited System menu contract (About + conditional Status + conditional API Explorer + conditional Pub/Sub Inspector) and state-id title rendering while adding FDC3 status affordances.
- FR-01417: TraderX publishes `traderx.account` context when a user changes the selected account in the main Trade view.
- FR-01418: TraderX consumes inbound `traderx.account` context and updates account-scoped views without rebroadcast loops.
- FR-01419: TraderX exposes a standalone `/mini-traderx` Angular route that can be launched as an independent FDC3 app/window.
- FR-01420: Mini TraderX displays the current account, current `fdc3.instrument`, current price, live P&L summary, and a position blotter filtered to the active instrument.
- FR-01421: Mini TraderX listens for and broadcasts both `fdc3.instrument` and `traderx.account` so account and instrument selection can originate from the main TraderX view or the mini view.
- FR-01422: Mini TraderX must be published through the TraderX-owned App Directory source and seeded into the default TraderX demo workspace in Sail.
- FR-01423: TraderX must expose an App Directory endpoint behind TraderX ingress for TraderX-owned apps, using the FDC3 App Directory REST contract (`/v2/apps`) while publishing FDC3 v3-compatible app metadata.
- FR-01424: Sail should support multiple App Directory sources for the demo through preconfigured startup configuration, including environment-variable driven source lists for repeatable local and CI runs.
- FR-01425: Sail should support adding and removing App Directory sources at runtime through a GUI so demo operators can add TraderX or third-party app marketplaces without editing Sail source.

## Non-Functional Requirements

- NFR-01401: The app-side FDC3 integration must target FDC3 `3.0.0-alpha.2` APIs using the official `@finos/fdc3` package and `getAgent()` semantics documented for FDC3 v3/Next.
- NFR-01402: App metadata (AppD/interoperability metadata in generated output) must declare supported inbound intents and context types.
- NFR-01403: FDC3 listener registration must occur during frontend startup and complete before user interaction begins.
- NFR-01404: Context publication must be deduplicated to avoid noisy repeated broadcasts for unchanged ticker selection.
- NFR-01405: Integration must not introduce new backend API or database schema dependencies for core FDC3 flows.
- NFR-01406: Structured frontend logs must expose inbound/outbound FDC3 actions for troubleshooting without leaking account-sensitive data.
- NFR-01407: Automated tests must cover context mapping, inbound/outbound intent handling, degraded mode (no agent), and end-to-end demo interoperability.
- NFR-01408: Sail sidecar runtime must be reproducible through generated artifacts (container definition + start/status/stop flow) without manual GUI-only setup steps.
- NFR-01409: Sidecar startup must not modify or block TraderX core ingress/service ports.
- NFR-01410: TraderX interoperability payloads must remain canonical and bare (`fdc3.instrument.id.ticker` only) with no Sail-widget-specific exchange aliasing in TraderX UI code.
- NFR-01411: Any Sail-specific compatibility logic must be isolated to generated Sail bootstrap patch assets and tracked as temporary technical debt for replacement by stable Sail v3 configuration hooks where available.
- NFR-01412: Because DesktopAgent callback behavior can be inconsistent in current Sail demo environments, TraderX may use a bounded context-sync fallback (for example active-channel `getCurrentContext` polling + dedupe) to preserve deterministic ticket-launch behavior. This fallback must be isolated, documented as technical debt, and removable when robust Sail event delivery is available.
- NFR-01413: Generated state-014 frontend manifests must depend on `@finos/fdc3@3.0.0-alpha.2` and must not use the retired `@robmoffat/fdc3-get-agent` bootstrap package.
- NFR-01414: The `traderx.account` context is a TraderX demo context type and must carry account identity only; it must not expose account balances, positions, or sensitive account attributes in FDC3 payloads.
- NFR-01415: TraderX-hosted App Directory responses must be deterministic, cache-safe for local demos, and must not require Sail-specific fixture editing to discover TraderX-owned apps.

## Technical Debt Register

- TD-01401: Sail demo interoperability currently relies on tactical runtime patching of the Sail v3 beta workspace; replace this with stable Sail configuration hooks once available.
- TD-01402: Symbol interoperability across apps remains ticker-centric and not fully normalized to CDM-grade symbology; this should be upgraded to canonical multi-identifier handling (for example CDM-backed FIGI/ISIN/RIC strategy) in a follow-on state.
- TD-01403: Remove the FDC3 `3.0.0-alpha.2` prerelease pin once FDC3 v3 is generally available and the main branch can track the stable release.
- TD-01404: Replace Sail-side app fixture injection with multi-App Directory source loading once Sail exposes stable startup and GUI configuration for additional app directories.

## Success Criteria

- SC-01401: Selecting a TraderX blotter row updates at least one external FDC3 demo app via `fdc3.instrument`.
- SC-01402: Raising `ViewChart` or `ViewQuote` from TraderX routes correctly through the desktop agent.
- SC-01403: Triggering `TraderX.CreateTradeTicket` or `TraderX.CreateOrderTicket` opens TraderX with ticker prefilled.
- SC-01404: `ViewOrders` intent opens TraderX orders view filtered by ticker.
- SC-01405: Regression tests show no breakage in baseline trade/order/position behavior when FDC3 agent is unavailable.
- SC-01406: State smoke test path is implemented (`scripts/test-state-014-fdc3-intent-interoperability.sh`) and includes FDC3-specific assertions.
- SC-01407: Local demo mode can launch TraderX + Sail + TraderX Intent Launcher + TradingView/Pricer demo apps and execute the end-to-end script without manual app-directory editing.
- SC-01408: Smoke checks validate that generated frontend output still satisfies inherited state-aware header/System-menu contract after adding FDC3 header affordances.
- SC-01409: In the seeded Sail workspace, Mini TraderX follows an instrument broadcast from main TraderX and updates its filtered live position view.
- SC-01410: Account selection in main TraderX is reflected in Mini TraderX through `traderx.account`, and selecting an account in Mini TraderX broadcasts the same context type.
- SC-01411: Sail can discover TraderX, Mini TraderX, and TraderX Intent Launcher from a TraderX-owned App Directory source rather than only from a Sail-local fixture.
