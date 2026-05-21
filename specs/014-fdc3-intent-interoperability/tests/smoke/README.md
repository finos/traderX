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

- Receiving `fdc3.instrument` updates TraderX UI scope/filter to the target ticker.
- Invalid/malformed context payloads are safely ignored with diagnostics.

## Intent Handling

- `ViewOrders` opens orders view filtered to ticker.
- `TraderX.CreateTradeTicket` opens prefilled trade ticket.
- `TraderX.CreateOrderTicket` opens prefilled order ticket.
- Outbound `ViewChart` and `ViewQuote` intent actions resolve via DesktopAgent.

## Cross-App Demo Validation

- In local Sail mode, context and intent round-trips succeed between TraderX and at least one additional app.

```bash
./scripts/test-state-014-fdc3-intent-interoperability.sh http://localhost:8080 http://localhost:8090
```
