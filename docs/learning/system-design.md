# System Design

State: `007-messaging-nats-replacement`

## Design Intent

State 007 replaces Socket.IO trade-feed messaging with NATS while preserving state 003 containerized runtime and ingress entry model.

## Runtime Topology / Flow (Spec Extract)

# Runtime Topology: 007 Messaging NATS Replacement

Parent state: `003-containerized-compose-runtime`

## Entrypoints

- Browser/UI ingress: `http://localhost:8080`
- NATS client port (internal compose network): `4222`
- NATS monitoring (optional local): `8222`
- NATS websocket ingress path (proxied): `/nats-ws`

## Components

- `nats-broker` replaces messaging role previously handled by `trade-feed`.
- `trade-service` publishes `trades.new`.
- `trade-processor` consumes `trades.new` and publishes account-scoped trade/position updates.
- `web-front-end-angular` subscribes to account-scoped update subjects through `nats.ws`.

## Networking

- Service-to-service messaging uses NATS TCP over compose network.
- Browser real-time stream uses WebSocket upgrade through ingress path `/nats-ws`.
- Existing REST routing through ingress remains unchanged.

## Startup / Health Order

- `nats-broker` must be healthy before trade-service/trade-processor startup.
- Frontend may start before broker, but stream subscriptions must retry until broker and websocket path are available.

## Source-of-Truth Files

- `system/messaging-subject-map.md`
- `system/docker-compose.nats.snippet.yaml`
- `system/ingress-nginx.nats-ws.snippet.conf`
