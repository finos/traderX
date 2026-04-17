# Runtime Topology: 014-fdc3-intent-interoperability

Parent state: `012-platform-convergence-c3`

Describe runtime topology and network/data flow changes introduced by this state.

## Entrypoints

- TraderX browser/UI/API entrypoint remains `http://localhost:8080`.
- Existing websocket path remains `ws(s)://<host>/nats-ws` for pricing/realtime feeds.
- Local Sail sidecar entrypoint: `http://localhost:8090`.
- Optional external desktop-agent/app profile entrypoints remain environment-defined.

## Components

- Inherits C3 runtime components from state `012`.
- Adds frontend interop layer in Angular UI:
  - FDC3 agent bootstrap/capability detection
  - context mapper + normalization utilities
  - inbound context listeners
  - inbound/outbound intent handlers
- Adds local Sail sidecar service (Dockerized or equivalent generated runtime) that hosts:
  - Sail web desktop agent UI
  - seeded app-directory records (TraderX + demo apps)
- External interoperating demo apps connect through Sail-mediated FDC3 APIs.

## Networking

- No new backend service-to-service network links are required.
- FDC3 message exchange occurs in desktop/browser runtime through DesktopAgent APIs.
- Existing REST routes (`/trade-service`, `/position-service`, `/order-matcher`) remain unchanged and are reused for intent-driven UI workflows.
- Sail sidecar is not fronted by TraderX ingress; it is exposed directly on its own port.

## Startup / Health Order

1. Start inherited C3 runtime (`012`) and verify TraderX endpoint health.
2. Start local Sail sidecar runtime and verify `http://localhost:8090` health.
3. Load TraderX UI and Sail UI in the same desktop demo session.
4. Register TraderX listeners for configured contexts/intents.
5. Validate app-directory entries and resolver visibility for TraderX ticket intents.
6. Validate graceful fallback path when agent is missing/unavailable.
