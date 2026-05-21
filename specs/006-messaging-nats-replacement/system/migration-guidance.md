# Migration Guidance: Socket.IO to NATS

## Goal

Perform an incremental transport migration from Socket.IO trade-feed to NATS with minimal functional disruption.

## Backend Service Migration

### trade-service

- Replace Socket.IO publish client usage with NATS publish client.
- Publish validated trade events on `trades.new`.

### trade-processor

- Replace Socket.IO subscribe client with NATS subscription to `trades.new`.
- Publish account-scoped update events:
  - `trades.account.<accountId>.updated`
  - `positions.account.<accountId>.updated`

### account-service / position-service / others

- Keep existing REST behavior unchanged.
- Add NATS integration only if service-specific event consumption is required.

## Frontend Migration

- Replace Socket.IO subscription client with `nats.ws`.
- Connect through ingress websocket route (`/nats-ws`).
- Subscribe to account-scoped wildcard subjects for selected account.

## Cutover Strategy

1. Introduce NATS broker and subject mapping in parallel spec artifacts.
2. Migrate producers first (trade-service).
3. Migrate consumers (trade-processor, frontend stream path).
4. Remove trade-feed runtime references after conformance checks pass.

## Post-Migration

- Validate baseline flows F2/F4 still pass.
- Keep JetStream and durable replay out of scope for this state; add in a future state.
