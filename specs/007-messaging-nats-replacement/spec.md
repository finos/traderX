# Feature Specification: Messaging Layer Replacement with NATS

**Feature Branch**: `007-messaging-nats-replacement`  
**Created**: 2026-03-31  
**Status**: Planned  
**Input**: Transition delta from `003-containerized-compose-runtime`

## User Stories

- As a service developer, I want backend eventing to use a robust protocol-native broker instead of Socket.IO conventions.
- As a frontend developer, I want real-time updates to keep working through ingress using a documented WebSocket path.
- As a maintainer, I want messaging topics/contracts documented so cross-language implementations stay consistent.
- As an operator, I want local and Compose startup for messaging to remain simple.

## Functional Requirements

- FR-701: The architecture SHALL replace Socket.IO-based `trade-feed` with `nats-broker` as the messaging backbone.
- FR-702: Trade submission flow SHALL continue publishing new-trade events consumed by trade-processor.
- FR-703: Trade-processor SHALL continue publishing account-scoped updates consumed by frontend clients.
- FR-704: Existing user-visible baseline flows from state `003` (trade submit, blotter/position updates, account workflows) SHALL remain behaviorally compatible.
- FR-705: Subject naming and event payload contracts SHALL be documented in `system/messaging-subject-map.md`.
- FR-706: Migration path SHALL document backend client replacement strategy and frontend `nats.ws` migration.
- FR-707: Realtime position updates in the frontend SHALL preserve baseline aggregate blotter behavior by updating an existing row in place for the same security key.

## Non-Functional Requirements

- NFR-701: Broker runtime SHALL use a lightweight NATS container image suitable for local Compose development.
- NFR-702: Broker connectivity SHALL support Java, .NET, Node.js, and Python clients used in TraderX states.
- NFR-703: Browser streaming SHALL be supported through NATS WebSocket endpoint via ingress proxying.
- NFR-704: Messaging topology SHALL support wildcard subscription patterns for account-scoped streams.
- NFR-705: Architecture SHALL remain incrementally extensible for optional JetStream durability in future states.
- NFR-706: This state SHALL preserve state `003` ingress and compose simplicity constraints unless explicitly changed.

## Success Criteria

- SC-701: Compose-level NATS service and ingress websocket proxy snippets are present in `system/`.
- SC-702: Spec pack includes migration guidance for backend and frontend client cutover from Socket.IO.
- SC-703: Conformance and smoke requirements for messaging replacement are documented.
- SC-704: Generation hook and smoke script paths exist for state `007`.
- SC-705: Frontend position blotter realtime updates do not create duplicate rows for the same security.
