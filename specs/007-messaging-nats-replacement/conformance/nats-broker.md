# nats-broker Conformance Pack

## User Stories

- backend services can communicate over a shared, robust broker.
- frontend can receive live updates over websocket via ingress.

## Functional Requirements

- `FR-701`
- `FR-702`
- `FR-703`
- `FR-704`
- `FR-705`
- `FR-707`

## Non-Functional Requirements

- `NFR-701`
- `NFR-702`
- `NFR-703`
- `NFR-704`

## Acceptance Criteria

- NATS service is reachable and healthy in state runtime.
- Trade events published by trade-service are consumed by trade-processor.
- Account-scoped updates are observable by frontend stream subscriber.
- Realtime position updates preserve aggregate blotter semantics (existing security rows update in place).

## Verification References

- `scripts/start-state-007-messaging-nats-replacement-generated.sh` (planned)
- `scripts/test-state-007-messaging-nats-replacement.sh` (planned)
