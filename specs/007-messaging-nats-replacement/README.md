# Feature Pack 007: Messaging Layer Replacement with NATS

Status: Planned  
Track: `architecture`  
Previous state: `003-containerized-compose-runtime`

## Motivation

State `003` uses a Socket.IO trade-feed service for both inter-service events and browser streaming.  
This pack introduces NATS as the messaging backbone to improve protocol clarity, multi-language interoperability, and operational robustness while keeping behavior compatible for existing flows.

The core direction is:

- replace `trade-feed` Socket.IO bus with a `nats-broker` component,
- standardize backend pub/sub on NATS subjects,
- expose browser-compatible real-time streaming using NATS WebSocket support through ingress,
- keep migration incremental and reversible through explicit spec deltas.

## Why NATS

- lightweight single-binary broker, easy local and containerized startup,
- strong client support across Java, .NET, Node.js, and Python,
- clean subject-based routing with wildcard subscriptions,
- built-in request/reply and optional JetStream durability for future states,
- browser support through `nats.ws` over WebSocket.

## Scope In This State

- Runtime base remains Docker Compose and NGINX ingress from `003`.
- Functional behavior for baseline trade/account/position flows remains unchanged.
- Messaging transport and event topology are replaced.
- Old Socket.IO trade-feed runtime is removed from the target architecture.

## Artifacts

- `spec.md`
- `requirements/functional-delta.md`
- `requirements/nonfunctional-delta.md`
- `contracts/contract-delta.md`
- `fidelity-profile.md`
- `components/nats-broker.md`
- `components/messaging-migration.md`
- `conformance/nats-broker.md`
- `system/architecture.model.json`
- `system/runtime-topology.md`
- `system/migration-guidance.md`
- `system/messaging-subject-map.md`
- `system/docker-compose.nats.snippet.yaml`
- `system/ingress-nginx.nats-ws.snippet.conf`
- `generation/generation-hook.md`
- `tests/smoke/README.md`

## Decision Record

- ADR: [`docs/adr/005-state-007-use-nats-for-messaging-replacement.md`](/docs/adr/005-state-007-use-nats-for-messaging-replacement)
