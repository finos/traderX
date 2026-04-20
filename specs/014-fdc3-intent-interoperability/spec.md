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
- FR-01410: Sail sidecar must include an app directory record for TraderX with declared inbound intent handlers (`ViewOrders`, `TraderX.CreateTradeTicket`, `TraderX.CreateOrderTicket`) and supported context (`fdc3.instrument`).
- FR-01411: Sail sidecar must include at least two additional demo apps (for example chart/quote/workbench apps) that can participate in symbol-driven workflows with TraderX.
- FR-01412: Sail sidecar must remain externally reachable directly (for example `http://localhost:8090`) and MUST NOT be routed through TraderX ingress.
- FR-01413: The default Sail bootstrap client-state for this feature must provide a two-tab demo layout:
  - tab `One`: chart + pricing + ticket-launch controls (`TraderX.CreateTradeTicket` and `TraderX.CreateOrderTicket`)
  - tab `Two`: news-oriented view.
- FR-01414: The feature pack and generated state README must include an explicit operator demo script with ordered steps and expected outcomes for the two-tab layout.

## Non-Functional Requirements

- NFR-01401: The app-side FDC3 integration must target FDC3 2.2 APIs using `@finos/fdc3` and `getAgent()` semantics.
- NFR-01402: App metadata (AppD/interoperability metadata in generated output) must declare supported inbound intents and context types.
- NFR-01403: FDC3 listener registration must occur during frontend startup and complete before user interaction begins.
- NFR-01404: Context publication must be deduplicated to avoid noisy repeated broadcasts for unchanged ticker selection.
- NFR-01405: Integration must not introduce new backend API or database schema dependencies for core FDC3 flows.
- NFR-01406: Structured frontend logs must expose inbound/outbound FDC3 actions for troubleshooting without leaking account-sensitive data.
- NFR-01407: Automated tests must cover context mapping, inbound/outbound intent handling, degraded mode (no agent), and end-to-end demo interoperability.
- NFR-01408: Sail sidecar runtime must be reproducible through generated artifacts (container definition + start/status/stop flow) without manual GUI-only setup steps.
- NFR-01409: Sidecar startup must not modify or block TraderX core ingress/service ports.
- NFR-01410: TraderX interoperability payloads must remain canonical and bare (`fdc3.instrument.id.ticker` only) with no Sail-widget-specific exchange aliasing in TraderX UI code.
- NFR-01411: Any widget-specific compatibility logic needed for Sail demo interoperability (for example exchange qualification or symbol format mapping for TradingView widgets) must be implemented as generated Sail-side patchwork assets applied pre-build/startup, and tracked as temporary technical debt for replacement by future CDM-native symbology.
- NFR-01412: Because DesktopAgent callback behavior can be inconsistent in current Sail demo environments, TraderX may use a bounded context-sync fallback (for example active-channel `getCurrentContext` polling + dedupe) to preserve deterministic ticket-launch behavior. This fallback must be isolated, documented as technical debt, and removable when robust Sail event delivery is available.

## Technical Debt Register

- TD-01401: Sail demo interoperability currently relies on tactical widget/runtime workarounds (for example TradingView symbol qualification and callback-delivery fallback behavior) that should be replaced by robust Sail-side event semantics and standardized interop contracts.
- TD-01402: Symbol interoperability across apps remains ticker-centric and not fully normalized to CDM-grade symbology; this should be upgraded to canonical multi-identifier handling (for example CDM-backed FIGI/ISIN/RIC strategy) in a follow-on state.

## Success Criteria

- SC-01401: Selecting a TraderX blotter row updates at least one external FDC3 demo app via `fdc3.instrument`.
- SC-01402: Raising `ViewChart` or `ViewQuote` from TraderX routes correctly through the desktop agent.
- SC-01403: Triggering `TraderX.CreateTradeTicket` or `TraderX.CreateOrderTicket` opens TraderX with ticker prefilled.
- SC-01404: `ViewOrders` intent opens TraderX orders view filtered by ticker.
- SC-01405: Regression tests show no breakage in baseline trade/order/position behavior when FDC3 agent is unavailable.
- SC-01406: State smoke test path is implemented (`scripts/test-state-014-fdc3-intent-interoperability.sh`) and includes FDC3-specific assertions.
- SC-01407: Local demo mode can launch TraderX + Sail + demo apps and execute the end-to-end script without manual app-directory editing.
