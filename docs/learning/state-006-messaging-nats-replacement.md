---
title: "State 006: Messaging Layer Replacement with NATS"
pagination_prev: null
pagination_next: null
---

# State 006 Learning Guide

<!-- Generated from specs/006-messaging-nats-replacement/learning-contract.json; edit the source. -->

## Separate messaging semantics from transport

A messaging replacement changes more than a connection string. For developers who understand the booking flow, this chapter follows that flow through NATS and asks what publishing, reconnecting and recording a business result each establish.

[How to learn with TraderX states](/docs/learning/how-to-learn)

**Maturity:** implemented. Run the exercises in a disposable local environment; use the quickstart for setup and cleanup.

### Starting point

The PostgreSQL state still uses the earlier messaging transport.

Entry route: **combined**. Bring the knowledge from every declared predecessor.

#### From 005-postgres-database-replacement

[Predecessor guide](/docs/learning/state-005-postgres-database-replacement)

- **Carry forward:** Move persistence to PostgreSQL while retaining account, trade and position behavior.
- **Why move:** The PostgreSQL state still uses the earlier messaging transport.
- **Add or revise:** Replace internal messaging with NATS while preserving the trade-to-position workflow.
- **Evidence to collect:** NATS carries the internal event while the business result remains recognizable. Subject names and payload fields determine interoperability. Reconnection establishes a new connection, not proof of recovery of every missed event. Check the configured messaging mode before making delivery claims.
- **Objectives:** `trace-increment`, `interpret-evidence`

| Before | After |
| --- | --- |
| The PostgreSQL state still uses the earlier messaging transport. | Replace internal messaging with NATS while preserving the trade-to-position workflow. |

### Concepts before tools

- A subject names an event channel. Publishing, receiving and committing a business change are separate events; transport availability alone does not guarantee replay or exactly-once processing.

**Runtime prerequisites:** Use the state quickstart for tool versions, generation, start and stop commands. Run one local state at a time because ports and generated output directories are shared.

### Learning objectives

- **trace-increment:** Trace a trade’s subject and payload from publisher to subscriber and reconcile its persisted business result.
- **interpret-evidence:** Explain the evidence boundary: Reconnection establishes a new connection, not proof of recovery of every missed event. Check the configured messaging mode before making delivery claims.

### Guided walkthrough

#### 1. observe (available)

Objectives: `trace-increment`.

Start this state, run the quickstart smoke checks, and trace one small trade through the messaging subject map and publisher/subscriber code. Record the trade identifier in the resulting trade and position views.

**Expected observation and meaning:** NATS carries the internal event while the business result remains recognizable. Subject names and payload fields determine interoperability.

Supporting material: [quickstart](/specs/messaging-nats-replacement/quickstart) · [architecture](/specs/messaging-nats-replacement/system/architecture) · [runtime-topology](/specs/messaging-nats-replacement/system/runtime-topology).

#### 2. challenge (available)

Objectives: `interpret-evidence`.

In a disposable demo, restart the NATS service identified in Compose and observe subscriber reconnection. Compare a trade submitted after recovery with prior records; do not assume events sent during an outage are replayed.

**Expected observation and meaning:** Reconnection establishes a new connection, not proof of recovery of every missed event. Check the configured messaging mode before making delivery claims.

Supporting material: [spec](/specs/messaging-nats-replacement/spec) · [contract-delta](/specs/messaging-nats-replacement/contracts/contract-delta).

### Demonstrate your understanding

**Question (`trace-increment`, `interpret-evidence`):** What evidence distinguishes broker recovery from business recovery?

**Assessment guidance:** Show the connection returning and separately reconcile the relevant trade identifiers and positions. State the configured delivery limitations.

### Scope and limitations

- Reconnection establishes a new connection, not proof of recovery of every missed event. Check the configured messaging mode before making delivery claims.
- This is an educational local demonstration. Passing its checks does not establish production readiness, financial settlement, or correctness under every failure mode.


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
