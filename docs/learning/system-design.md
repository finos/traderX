# System Design

State: `010-pricing-awareness-market-data`

## Design Intent

State 010 builds on NATS-based runtime from 007 and adds synthetic market pricing, trade execution price stamping, position cost basis aggregation, and frontend valuation.

## Runtime Topology / Flow (Spec Extract)

# Runtime Topology: 010 Pricing Awareness and Market Data

Parent state: `007-messaging-nats-replacement`

## Entrypoints

- Browser/UI ingress: `http://localhost:8080`
- NATS client port (internal compose network): `4222`
- NATS monitoring (optional local): `8222`
- NATS websocket ingress path (proxied): `/nats-ws`
- Price publisher REST: `http://localhost:18100`

## Components

- `nats-broker` remains core messaging bus from state `007`.
- `price-publisher` publishes `pricing.<TICKER>` market ticks.
- `trade-service` enriches orders with execution `price` via `price-publisher`.
- `trade-processor` persists `trade.price` and `position.averageCostBasis`.
- `web-front-end-angular` subscribes to account updates and `pricing.*`.

## Networking

- Service-to-service messaging uses NATS TCP over compose network.
- Browser real-time stream uses WebSocket upgrade through ingress path `/nats-ws`.
- Price publisher is available via ingress path `/price-publisher/` and direct local port `18100`.

## Startup / Health Order

- `nats-broker` and `price-publisher` must be healthy before trade-service startup.
- Frontend may start before broker/price streams, but subscriptions must retry until available.

## Source-of-Truth Files

- `system/messaging-subject-map.md`
- `system/docker-compose.nats.snippet.yaml`
- `system/ingress-nginx.nats-ws.snippet.conf`
