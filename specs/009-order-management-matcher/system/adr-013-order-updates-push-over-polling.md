# ADR-013: Order UI Updates Use Push Topics (Not Polling)

## Status
Accepted

## Date
2026-04-14

## Context

State 009 added order management with account and admin order views.
The initial implementation used periodic `GET /orders` polling in the Angular order views.
This created visible latency between backend state transitions and UI updates, and diverged from existing real-time patterns already used for trades and positions.

FR-01306 requires order flows to be propagated in realtime via messaging subjects.
To satisfy this end-to-end (backend and frontend), order state transitions must be published onto trade-feed topics and consumed directly by the browser.

## Decision

1. Order matcher publishes order updates for each persisted lifecycle transition to:
- `/accounts/{accountId}/orders`
- `/orders`

2. Event payload contract matches the order REST response shape so UI consumers can update local row state without immediate follow-up HTTP fetches.

3. Angular order views retain an initial load (`GET /orders?status=open...`) for bootstrap state, then switch to push subscriptions for live updates.

4. Periodic polling loops for order view freshness are removed from state 009 order UIs.

## Consequences

- Lower end-to-end UI latency for order create/fill/cancel/force-fill events.
- Consistent live-data model across trades, positions, and orders.
- Lower steady-state HTTP load from order view refresh traffic.
- Runtime behavior now depends on trade-feed topic health and order publisher connectivity; this is acceptable and aligned with the platform messaging model.
