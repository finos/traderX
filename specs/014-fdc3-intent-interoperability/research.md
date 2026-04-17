# Research: FDC3 Intent Interoperability on C3

## Objective

Define an implementation-ready interoperability layer that lets TraderX participate in desktop workflows through FDC3 contexts and intents without disrupting C3 baseline behavior.

## Inputs Reviewed

- `spec.md`
- `plan.md`
- `tasks.md`
- `system/runtime-topology.md`
- state `009` order-management and blotter interaction patterns (ticker-centric order/trade/position UX)
- state `012` convergence baseline/runtime expectations
- FINOS FDC3 2.2 intent/context usage patterns for app-level integration
- local Sail runtime behavior and app-directory model (browser mode)

## Key Decisions

1. Implement app-side FDC3 behavior only; do not scope desktop-agent implementation into TraderX.
2. Use `fdc3.instrument` as the canonical interoperability context because TraderX UX is ticker-centric.
3. Prioritize standard intents for broad compatibility (`ViewOrders`, `ViewChart`, `ViewQuote`).
4. Add two explicit custom intents for demo and workflow value:
   - `TraderX.CreateTradeTicket`
   - `TraderX.CreateOrderTicket`
5. Keep backend APIs unchanged; implement interop mappings and listeners in the Angular frontend.
6. Treat FDC3 availability as optional at runtime and preserve baseline behavior when absent.
7. Package a local Sail sidecar runtime as part of state `014` demo path.
8. Keep Sail outside TraderX ingress (separate service boundary, separate port) for operational clarity.

## Risks and Mitigations

- Risk: inconsistent symbol mapping between TraderX entities and FDC3 payloads.
  - Mitigation: one shared normalization/mapping module with unit coverage.
- Risk: context-event storms from repeated selection changes.
  - Mitigation: deduplicate publishes for unchanged ticker and debounce rapid re-selection.
- Risk: intent handlers alter UI in invalid account scope.
  - Mitigation: enforce existing ticket/account validation paths for intent-driven launches.
- Risk: environment variability across desktop agents.
  - Mitigation: maintain mocked integration tests plus local Sail-based compatibility checks.
- Risk: Sail setup drift makes demos brittle.
  - Mitigation: version app-directory assets in-state and provide scripted startup checks.
- Risk: widget-specific symbology requirements leak into TraderX frontend and create app-coupled payload behavior.
  - Mitigation: keep TraderX payloads canonical (`ticker` only) and isolate widget-specific symbol qualification inside Sail-side TradingView override assets applied at startup.
