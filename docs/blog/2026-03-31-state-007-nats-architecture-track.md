---
title: "State 006: Swapping Socket.IO for NATS"
date: 2026-03-31
description: "TraderX state 006 moves from a brittle Socket.IO messaging layer to NATS, establishes the architecture-track messaging baseline, and shows why SpecKit accelerated delivery and documentation."
---

# State 006: Swapping Socket.IO for NATS

Published: **Tuesday, March 31, 2026**

State `006-messaging-nats-replacement` is in place as the messaging architecture transition on top of `005-postgres-database-replacement`.

For a long time, TraderX used a deliberately simple messaging layer that was easy to run but increasingly brittle as we pushed toward more realistic multi-service evolution. The old Socket.IO-centric setup worked, but it forced us into awkward conventions for server-to-server eventing and created fragility when we wanted clearer protocol behavior.

## What Changed

We replaced the `trade-feed` Socket.IO runtime role with a `nats-broker` component and migrated eventing to NATS subjects.

This change keeps baseline user flows intact, but modernizes the transport layer:

- backend pub/sub now uses a broker pattern designed for service-to-service communication,
- browser streaming now uses NATS WebSocket routing through ingress (`/nats-ws`),
- runtime remains approachable in Docker Compose for this branch.

Code and specs:

- State spec pack: [/specs/messaging-nats-replacement](/specs/messaging-nats-replacement)
- State learning guide: [/docs/learning/state-006-messaging-nats-replacement](/docs/learning/state-006-messaging-nats-replacement)
- Generated code branch: [code/generated-state-006-messaging-nats-replacement](https://github.com/finos/traderX/tree/code/generated-state-006-messaging-nats-replacement)
- Compare against parent state `004`: [generated-state 005...005](https://github.com/finos/traderX/compare/code%2Fgenerated-state-005-postgres-database-replacement...code%2Fgenerated-state-006-messaging-nats-replacement)

## Why NATS

We selected NATS because it is a better fit for this stage of TraderX evolution:

- lightweight and simple to operate locally,
- strong multi-language clients (Java, .NET, Node.js, Python),
- clean subject model and wildcard subscriptions,
- request/reply support with room for future durability extension,
- browser support through websocket-compatible clients.

The formal state-scoped rationale is captured in:

- [ADR-005 Use NATS for State 006 Messaging Replacement](/docs/adr/005-state-006-use-nats-for-messaging-replacement)

## Why This Was Easier With SpecKit

This change is a clear example of why we moved to SpecKit-first maintenance:

- requirements and deltas were defined once in the feature pack,
- code generation and runtime scripts were updated from that intent,
- docs and learning guides were regenerated with lineage and compare links,
- tests and conformance checks were updated as part of the same state delta.

Instead of manually curating long-lived code branches, we changed the system of record and regenerated state outputs.

## Track Implications

State `005` sets up the messaging baseline that later states inherit:

- `006` adds observability,
- `007` layers pricing streams on top of NATS,
- `008` layers order matching on top of pricing and NATS.

This keeps transitions explicit, diffs reviewable, and runnable outputs available at each step.
