# Functional Delta: 007 Messaging NATS Replacement

Parent state: `003-containerized-compose-runtime`

## Added

- Broker-backed subject contract for backend event publication/consumption.
- Broker-backed websocket stream path for frontend subscriptions.

## Changed

- Trade messaging transport changes:
  - from Socket.IO channels in `trade-feed`,
  - to NATS subjects in `nats-broker`.
- Event producer/consumer client logic in trade-service, trade-processor, and frontend stream subscriber.
- Frontend realtime position handling keeps baseline aggregate blotter semantics by upserting rows for existing securities.

## Removed

- Dedicated Socket.IO messaging service role (`trade-feed`) in target runtime topology.

## Flow Impact

- `F2` (trade submission and processing): publish/consume path changes to NATS.
- `F4` (real-time blotter updates): subscription path changes to NATS WebSocket.
- Startup sequencing and health checks include NATS broker readiness.
