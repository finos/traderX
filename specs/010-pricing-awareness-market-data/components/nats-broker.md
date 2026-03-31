# Component Spec: nats-broker

## Responsibilities

- Provide broker-based pub/sub for backend services.
- Provide websocket-compatible endpoint for browser streaming clients.
- Support wildcard subscriptions for account-scoped and pricing subjects.

## Covered Flows

- `F2` trade submission to processing event chain (with execution price enrichment).
- `F4` real-time account updates + pricing stream to UI.
- `STARTUP` runtime readiness dependency for event-producing services.

## Requirement Coverage

- `FR-1002`, `FR-1005`, `FR-1006`, `FR-1009`
- `NFR-1002`, `NFR-1003`, `NFR-1005`

## Interfaces

- NATS client: `4222`
- Monitoring: `8222` (optional debug)
- Browser websocket (proxied): `/nats-ws`

## Verification

- `scripts/test-state-010-pricing-awareness-market-data.sh` (to be implemented)
