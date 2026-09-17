# Smoke Tests: 014-fdc3-intent-interoperability

- Primary smoke script: `scripts/test-state-014-fdc3-intent-interoperability.sh`

Minimum state checks to implement:

## Runtime Baseline

- C3 runtime starts cleanly and core TraderX endpoints remain healthy.
- Existing trade/order/position workflows still function when FDC3 is unavailable.

## Sail Sidecar Runtime

- Sail sidecar starts and responds at `http://localhost:8090`.
- Sail sidecar is reachable independently of TraderX ingress.
- Seeded app-directory profile is loaded (TraderX app + selected demo apps).

## FDC3 Availability and Fallback

- Frontend detects DesktopAgent presence/absence without throwing runtime errors.
- Degraded mode hides/disables FDC3-only actions and preserves baseline interactions.

## Context Mapping and Publication

- Selecting a ticker-bearing trade/order/position row publishes valid `fdc3.instrument` context.
- Re-selecting same ticker does not emit duplicate context events beyond dedupe policy.

## Inbound Context Handling

- Receiving `fdc3.instrument` retains the ticker and updates only blotters that opted in.
- Invalid/malformed context payloads are safely ignored with diagnostics.

## Intent Handling

- `ViewOrders` opens orders and retains the ticker without enabling filtering.
- `TraderX.CreateTradeTicket` opens prefilled trade ticket.
- `TraderX.CreateOrderTicket` opens prefilled order ticket.
- Outbound `ViewChart` and `ViewQuote` intent actions resolve via DesktopAgent.

## Cross-App Demo Validation

- In local Sail mode, context and intent round-trips succeed between TraderX and at least one additional app.

```bash
./scripts/test-state-014-fdc3-intent-interoperability.sh http://localhost:8080 http://localhost:8090
```

## Opt-in ticker regression suite (#462)

After state generation, run `npx ng test --watch=false --browsers=ChromeHeadlessNoSandbox` in `generated/code/target-generated/web-front-end/angular`. The generated `blotter-ticker-filter.spec.ts` tests real Angular templates, AG Grid and the TraderX FDC3 adapter with controlled backend/agent boundaries. It covers independent modes, retained selection, malformed context, account changes, snapshot races and reconnect refresh.

For real DesktopAgent delivery, start the generated TraderX frontend and Sail default layout, then run:

```bash
FDC3_TICKER_FILTER_TEST=1 SAIL_URL=http://localhost:8090/html/ \
  bash scripts/test-state-014-fdc3-playwright-smoke.sh http://localhost:8080/trade
```

This path does not install a mock `window.fdc3`. It uses deterministic REST fixtures while exercising Sail's actual FDC3 transport between the embedded app and a newly opened window, including retained context, independent modes, tab persistence and keyboard operation. A healthy Sail runtime containing the TraderX default frame is required; connection or popout handshake failures fail the test.
