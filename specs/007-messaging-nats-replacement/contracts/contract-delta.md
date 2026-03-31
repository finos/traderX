# Contract Delta: 007 Messaging NATS Replacement

Parent state: `003-containerized-compose-runtime`

## OpenAPI Changes

- No REST OpenAPI contract changes required in this state.
- Existing service REST contracts from prior state remain valid.

## Event Contract Changes

Socket.IO channels are replaced by NATS subjects.

Canonical subject families:

- `trades.new` (trade submission events)
- `trades.processed` (trade lifecycle updates)
- `positions.account.<accountId>.updated`
- `trades.account.<accountId>.updated`

Payload compatibility goal:

- Keep semantic payload shape equivalent to prior state events where possible.
- Any payload/schema drift must be documented explicitly before implementation.

## Compatibility Notes

- Functional UX behavior should remain unchanged for baseline flows.
- Transport-level compatibility is not required (Socket.IO clients are replaced).
- Migration should proceed service-by-service with temporary dual-publish allowed only during cutover implementation.
