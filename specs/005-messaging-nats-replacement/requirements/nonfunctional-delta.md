# Non-Functional Delta: 007 Messaging NATS Replacement

Parent state: `003-containerized-compose-runtime`

## Runtime / Operations

- Messaging broker is a standalone NATS container (single binary, low operational overhead).
- Compose runtime adds NATS service and health gate before dependent service startup.
- Ingress supports NATS websocket upgrade path for browser clients.

## Security / Compliance

- Subject namespace design must avoid exposing internal-only subjects to browser subscriptions.
- Browser-visible subjects are limited to account-scoped streams via documented naming policy.
- No auth hardening changes are introduced in this state; auth/TLS hardening remains future non-functional states.

## Performance / Scalability

- Broker should support higher fan-out and lower overhead than Socket.IO trade-feed role.
- Subject-based routing with wildcards reduces application-layer channel orchestration complexity.

## Reliability / Observability

- Messaging topology supports request/reply and optional future JetStream durability without redesign.
- Broker health endpoint and connectivity checks are included in smoke/conformance expectations.
