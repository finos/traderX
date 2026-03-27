# Trade-Feed Functional Requirements

## Scope

Define baseline functional behavior for the next pure-generated cutover target: `trade-feed`.

## Functional Requirements

- FR-TF-001: The service shall expose a Socket.IO broker on port `18086` by default.
- FR-TF-002: The service shall support `subscribe` command with topic string payload and join the socket to that topic room.
- FR-TF-003: The service shall support `publish` command with `{ topic, payload, type? }` envelope and broadcast to the requested topic.
- FR-TF-004: Published messages shall also be broadcast to wildcard inspection topic `/*`.
- FR-TF-005: The service shall wrap outbound publish events with fields: `type`, `from`, `topic`, `date`, `payload`.
- FR-TF-006: The service shall expose `GET /` and return the broker inspector HTML page.
- FR-TF-007: For compatibility, the service shall accept both `unsubscribe` and legacy typo `unusbscribe` command names.
- FR-TF-008: Join/leave lifecycle events shall be emitted as publish messages using system sender identity.

## Out Of Scope

- No durable queue semantics in this phase.
- No authentication/authorization redesign in this phase.
- No broker technology replacement in this phase.
