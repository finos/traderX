# Component Spec: Messaging Migration Strategy

## Goal

Move all messaging traffic from Socket.IO conventions to NATS subject conventions while preserving functional behavior.

## Migration Targets

- `trade-service` publisher path
- `trade-processor` consumer/publisher path
- frontend stream subscriber path

## Phased Approach

1. Define subject map and payload compatibility (`system/messaging-subject-map.md`).
2. Implement backend NATS clients and event flow.
3. Implement frontend `nats.ws` subscription for account-scoped updates.
4. Remove Socket.IO trade-feed dependencies and runtime component.

## Compatibility Guardrail

Business workflows remain unchanged; only transport and routing semantics change.
