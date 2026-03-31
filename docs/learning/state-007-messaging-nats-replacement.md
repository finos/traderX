---
title: "State 007: Messaging Layer Replacement with NATS"
---

# State 007 Learning Guide

## Position In Learning Graph

- Previous state(s): [003-containerized-compose-runtime](/docs/learning/state-003-containerized-compose-runtime)
- Next state(s): none

## Rendered Code

- Generated branch: [code/generated-state-007-messaging-nats-replacement](https://github.com/finos/traderX/tree/code/generated-state-007-messaging-nats-replacement)
- Authoring branch (spec source): [feature/agentic-renovation](https://github.com/finos/traderX/tree/feature/agentic-renovation)

## Code Comparison With Previous State

- Compare against `003-containerized-compose-runtime`: [code/generated-state-003-containerized-compose-runtime...code/generated-state-007-messaging-nats-replacement](https://github.com/finos/traderX/compare/code%2Fgenerated-state-003-containerized-compose-runtime...code%2Fgenerated-state-007-messaging-nats-replacement)

## Plain-English Code Delta

- **Added:** Broker-backed subject contract for backend event publication/consumption.
- **Added:** Broker-backed websocket stream path for frontend subscriptions.
- **Changed:** Trade messaging transport changes:
- **Changed:** from Socket.IO channels in `trade-feed`,
- **Changed:** to NATS subjects in `nats-broker`.
- **Changed:** Event producer/consumer client logic in trade-service, trade-processor, and frontend stream subscriber.
- **Changed:** Frontend realtime position handling keeps baseline aggregate blotter semantics by upserting rows for existing securities.
- **Removed:** Dedicated Socket.IO messaging service role (`trade-feed`) in target runtime topology.

## Run This State

```bash
./scripts/start-state-007-messaging-nats-replacement-generated.sh
```

## Canonical Spec Links

- State spec pack: [/specs/messaging-nats-replacement](/specs/messaging-nats-replacement)
- Architecture: [/specs/messaging-nats-replacement/system/architecture](/specs/messaging-nats-replacement/system/architecture)
- Flows / topology: [/specs/messaging-nats-replacement/system/runtime-topology](/specs/messaging-nats-replacement/system/runtime-topology)
- State ADR: [link](/docs/adr/005-state-007-use-nats-for-messaging-replacement)
