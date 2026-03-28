# System Context (Baseline)

TraderX is a distributed sample trading platform composed of REST services, a pub/sub feed, a database process, and an Angular UI.

Authoritative context sources:

- `docs/overview.md` (C4 view and component topology)
- `docs/flows.md` (runtime sequence flows)
- `README.md` and `docs/README.md` (component runtime expectations)

## Baseline Runtime Shape

- Runtime style: pre-containerized local processes started in deterministic order.
- Communication:
  - REST for synchronous validation/query operations
  - Socket.IO pub/sub for trade and position events
  - H2 database over TCP/PG/Web ports for persistence and inspection
- UI scope for this migration baseline: Angular frontend.

## Baseline Service Set

- `database`
- `reference-data`
- `trade-feed`
- `people-service`
- `account-service`
- `position-service`
- `trade-processor`
- `trade-service`
- `web-front-end-angular`

Ingress is part of the broader platform model but is outside the baseline uncontainerized startup flow.
