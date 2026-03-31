---
title: ADR-005 Use NATS for State 007 Messaging Replacement
slug: /adr/005-state-007-use-nats-for-messaging-replacement
status: accepted
date: 2026-03-31
decision-makers: Dov Katz, TraderX maintainers
consulted: Core contributors
informed: TraderX users and contributors
---

# Use NATS as the Messaging Backbone in State 007

## Context and Problem Statement

The baseline and early states used a Socket.IO-based messaging service (`trade-feed`) for both backend event propagation and frontend live updates. This was intentionally simple, but it became brittle for architecture evolution:

- backend inter-process messaging was coupled to a browser-oriented protocol and conventions,
- eventing semantics were harder to reason about as the system evolved,
- multi-language service interoperability required extra glue and custom handling.

State `007-messaging-nats-replacement` introduces the first architecture-track branch from `003-containerized-compose-runtime`. We needed a lightweight but robust messaging foundation that remains easy for local users while improving correctness and extensibility.

State scope: this ADR applies specifically to state `007` and descendants that inherit its messaging model.

## Decision Drivers

* Improve backend pub/sub clarity and robustness without increasing local setup burden.
* Keep browser realtime streaming support for the Angular UI.
* Support Java, .NET, Node.js, and Python service clients.
* Keep incremental migration from state `003` possible and testable.
* Preserve simple containerized local runtime for contributors.

## Considered Options

* Keep Socket.IO trade-feed as-is.
* Replace trade-feed with NATS broker + subject model.
* Replace trade-feed with MQTT broker.

## Decision Outcome

Chosen option: "Replace trade-feed with NATS broker + subject model", because it provides the best balance of local simplicity, multi-language interoperability, and architecture clarity while preserving browser websocket support.

### Consequences

* Good, because backend eventing moves to a purpose-built messaging protocol with clear subjects.
* Good, because runtime remains lightweight and easy to run in Docker Compose.
* Good, because browser realtime remains available through ingress websocket routing.
* Good, because future states can add durability and richer patterns incrementally.
* Bad, because migration requires touching multiple services and frontend stream handling.
* Bad, because maintainers must preserve contract and flow compatibility during transport changes.

### Confirmation

Decision compliance is confirmed when:

* `trade-feed` is removed from state `007` runtime topology and replaced by `nats-broker`,
* trade submit and processing flows continue to pass conformance/smoke checks,
* frontend realtime trade/position updates remain functional via websocket route,
* generated code and docs retain state lineage and compareability against state `003`.

## Pros and Cons of the Options

### Keep Socket.IO trade-feed as-is

* Good, because no migration effort is required.
* Good, because existing behavior is already known.
* Bad, because backend messaging remains tied to browser-centric conventions.
* Bad, because architecture evolution keeps accumulating protocol friction.

### Replace trade-feed with NATS broker + subject model

* Good, because NATS is lightweight and straightforward for local/container use.
* Good, because subject routing and wildcard patterns fit account-scoped event streams.
* Good, because ecosystem support across TraderX service languages is strong.
* Neutral, because browser streaming still needs ingress websocket routing discipline.
* Bad, because migration requires cross-component coordination and test hardening.

### Replace trade-feed with MQTT broker

* Good, because MQTT is also lightweight and broadly supported.
* Good, because topic-based routing can fit event fan-out patterns.
* Bad, because it is less aligned with our immediate request/reply and service-pattern direction.
* Bad, because it adds selection ambiguity when the team already validated NATS pathing.

## More Information

Related state and artifacts:

* State pack: `/specs/messaging-nats-replacement`
* Learning guide: `/docs/learning/state-007-messaging-nats-replacement`
* Generated code branch: `code/generated-state-007-messaging-nats-replacement`
