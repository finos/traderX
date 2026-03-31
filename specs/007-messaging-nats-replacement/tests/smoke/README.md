# Smoke Tests: 007 Messaging NATS Replacement

- Primary smoke script: `scripts/test-state-007-messaging-nats-replacement.sh` (planned)

## Required Checks

1. Runtime startup includes healthy `nats-broker`.
2. Trade submission still accepted on existing REST path.
3. Trade service publish event reaches trade-processor through NATS.
4. Processed trade and position updates are published on account-scoped subjects.
5. Frontend stream subscriber receives account-scoped updates via websocket ingress path.
6. Unknown account/ticker validations remain unchanged from prior state.
