# State 007 Fidelity Profile

This profile captures the required technical shape for state `007-messaging-nats-replacement`.

## Runtime Stack Deltas From State 003

| Concern | State 003 | State 007 |
| --- | --- | --- |
| Messaging backbone | `trade-feed` (Socket.IO service) | `nats-broker` (NATS container) |
| Backend pub/sub protocol | Socket.IO semantics | NATS subjects |
| Browser real-time stream | Socket.IO websocket path | `nats.ws` websocket path via ingress |
| Ingress | NGINX | NGINX (extended with `/nats-ws`) |
| Runtime model | Docker Compose | Docker Compose |

## NATS Baseline Constraints

- Broker image should be lightweight and local-friendly (`nats:2.x`).
- Compose service exposes:
  - `4222` (client TCP),
  - `8222` (monitoring, optional local debug),
  - websocket endpoint mapped via ingress path.
- Subject conventions are defined in `system/messaging-subject-map.md`.

## Closeness Policy

State `007` is intentionally not source-close to the old trade-feed implementation; it is architecture-close to state `003` except for the messaging layer replacement.

Changes expected:

- removal of `trade-feed` runtime component,
- introduction of NATS client wiring in producer/consumer services,
- frontend stream client migration.
