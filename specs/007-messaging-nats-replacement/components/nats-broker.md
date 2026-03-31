# Component Spec: nats-broker

## Responsibilities

- Provide broker-based pub/sub for backend services.
- Provide websocket-compatible endpoint for browser streaming clients.
- Support subject wildcard subscriptions for account-scoped updates.

## Covered Flows

- `F2` trade submission to processing event chain.
- `F4` real-time update streaming to UI.
- `STARTUP` runtime readiness dependency for event-producing services.

## Requirement Coverage

- `FR-701`, `FR-702`, `FR-703`, `FR-705`
- `NFR-701`, `NFR-702`, `NFR-703`, `NFR-704`

## Interfaces

- NATS client: `4222`
- Monitoring: `8222` (optional debug)
- Browser websocket (proxied): `/nats-ws`

## Verification

- `scripts/test-state-007-messaging-nats-replacement.sh` (to be implemented)
