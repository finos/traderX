---
title: "State 006: Messaging Layer Replacement with NATS"
---

# State 006 Learning Guide

## Position In Learning Graph

- Previous state(s): [005-postgres-database-replacement](/docs/learning/state-005-postgres-database-replacement)
- Dotted-line parent(s): none
- Next state(s): [007-observability-lgtm-compose](/docs/learning/state-007-observability-lgtm-compose)

## Convergence Metadata

- Convergence state: `no`
- Convergence level: `none`
- Lineage role: `canonical`
- Nearest previous convergence: `none`
- Nearest next convergence: `none`

## Rendered Code

- Generated branch: [code/generated-state-006-messaging-nats-replacement](https://github.com/finos/traderX/tree/code/generated-state-006-messaging-nats-replacement)
- Authoring branch (spec source): [main](https://github.com/finos/traderX/tree/main)

## Code Comparison With Previous State

- Compare against `005-postgres-database-replacement`: [code/generated-state-005-postgres-database-replacement...code/generated-state-006-messaging-nats-replacement](https://github.com/finos/traderX/compare/code%2Fgenerated-state-005-postgres-database-replacement...code%2Fgenerated-state-006-messaging-nats-replacement)

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
./scripts/start-state-006-messaging-nats-replacement-generated.sh
```

## Canonical Spec Links

- State spec pack: [/specs/messaging-nats-replacement](/specs/messaging-nats-replacement)
- Architecture: [/specs/messaging-nats-replacement/system/architecture](/specs/messaging-nats-replacement/system/architecture)
- Flows / topology: [/specs/messaging-nats-replacement/system/runtime-topology](/specs/messaging-nats-replacement/system/runtime-topology)
- Research: [link](/specs/messaging-nats-replacement/research)
- Data model: [link](/specs/messaging-nats-replacement/data-model)
- Quickstart: [link](/specs/messaging-nats-replacement/quickstart)
- State ADR: [link](/docs/adr/005-state-006-use-nats-for-messaging-replacement)
