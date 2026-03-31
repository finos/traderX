# System Design

State: `002-edge-proxy-uncontainerized`

## Design Intent

State 002 keeps uncontainerized services and introduces an edge proxy as the single browser-facing entrypoint.

## Runtime Topology / Flow (Spec Extract)

# Runtime Topology (State 002)

State `002-edge-proxy-uncontainerized` keeps all baseline backend processes and adds one browser-facing edge proxy endpoint.

## Ports

- `18080` edge proxy (new)
- `18093` Angular dev server (kept as upstream to edge)
- backend service ports unchanged from state `001`

## Browser Access Model

- Browser enters only via `http://localhost:18080`.
- UI and API calls resolve through the same origin (`localhost:18080`).
- Direct browser cross-origin calls to backend service ports are no longer required.

## Route Prefixes

Defined in `system/edge-routing.json`:

- `/account-service` -> account-service (`18088`)
- `/reference-data` -> reference-data (`18085`)
- `/trade-service` -> trade-service (`18092`)
- `/position-service` -> position-service (`18090`)
- `/people-service` -> people-service (`18089`)
- `/socket.io` -> trade-feed (`18086`, websocket)
