---
title: "State 007: Swapping Socket.IO for NATS"
date: 2026-03-31
description: "TraderX state 007 moves from a brittle Socket.IO messaging layer to NATS, marks the first architecture-track branch from state 003, and shows why SpecKit accelerated delivery and documentation."
---

# State 007: Swapping Socket.IO for NATS

Published: **Tuesday, March 31, 2026**

State `007-messaging-nats-replacement` is now in place as our first major architecture-track breakout from `003-containerized-compose-runtime`.

For a long time, TraderX used a deliberately simple messaging layer that was easy to run but increasingly brittle as we pushed toward more realistic multi-service evolution. The old Socket.IO-centric setup worked, but it forced us into awkward conventions for server-to-server eventing and created fragility when we wanted clearer protocol behavior.

## What Changed

We replaced the `trade-feed` Socket.IO runtime role with a `nats-broker` component and migrated eventing to NATS subjects.

This change keeps baseline user flows intact, but modernizes the transport layer:

- backend pub/sub now uses a broker pattern designed for service-to-service communication,
- browser streaming now uses NATS WebSocket routing through ingress (`/nats-ws`),
- runtime remains approachable in Docker Compose for this branch.

Code and specs:

- State spec pack: [/specs/messaging-nats-replacement](/specs/messaging-nats-replacement)
- State learning guide: [/docs/learning/state-007-messaging-nats-replacement](/docs/learning/state-007-messaging-nats-replacement)
- Generated code branch: [code/generated-state-007-messaging-nats-replacement](https://github.com/finos/traderX/tree/code/generated-state-007-messaging-nats-replacement)
- Compare against parent state `003`: [generated-state 003...007](https://github.com/finos/traderX/compare/code%2Fgenerated-state-003-containerized-compose-runtime...code%2Fgenerated-state-007-messaging-nats-replacement)

## Why NATS

We selected NATS because it is a better fit for this stage of TraderX evolution:

- lightweight and simple to operate locally,
- strong multi-language clients (Java, .NET, Node.js, Python),
- clean subject model and wildcard subscriptions,
- request/reply support with room for future durability extension,
- browser support through websocket-compatible clients.

The formal state-scoped rationale is captured in:

- [ADR-005 Use NATS for State 007 Messaging Replacement](/docs/adr/005-state-007-use-nats-for-messaging-replacement)

## Why This Was Easier With SpecKit

This change is a clear example of why we moved to SpecKit-first maintenance:

- requirements and deltas were defined once in the feature pack,
- code generation and runtime scripts were updated from that intent,
- docs and learning guides were regenerated with lineage and compare links,
- tests and conformance checks were updated as part of the same state delta.

Instead of manually curating long-lived code branches, we changed the system of record and regenerated state outputs.

## Track Implications

State `007` proves the architecture track can branch independently from the DevEx track (`004/005/006`) while still sharing ancestry at `003`.

That unlocks useful combinations:

- Compose + NATS today (`007`),
- Kubernetes + NATS next (tentative `008` branch shown in the learning graph),
- parallel experimentation without forcing unrelated changes into one branch path.

This is exactly the learning model we wanted: explicit state transitions, clear diffs, and runnable outputs at each step.
