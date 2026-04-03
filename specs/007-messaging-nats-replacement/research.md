# Research: Messaging Layer Replacement with NATS

## Objective

Define the transition from state `003` to `007` by replacing Socket.IO trade-feed messaging with NATS-based messaging.

## Inputs Reviewed

- `spec.md`
- `plan.md`
- `tasks.md`
- `requirements/functional-delta.md`
- `requirements/nonfunctional-delta.md`
- `system/architecture.md`
- `system/runtime-topology.md`

## Key Decisions

1. Use NATS subjects for backend pub/sub and frontend streaming integration.
2. Preserve core trade lifecycle and account-scoped update semantics.
3. Keep this architecture branch composable with future devex and functional tracks.
