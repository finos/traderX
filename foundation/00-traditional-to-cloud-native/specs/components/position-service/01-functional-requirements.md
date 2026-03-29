# Position-Service Functional Requirements

## Scope

Define baseline functional behavior for the next pure-generated cutover target: `position-service`.

## Functional Requirements

- FR-POS-001: The service shall expose `GET /trades/{accountId}` and return trades for the specified account.
- FR-POS-002: The service shall expose `GET /trades/` and return all trades.
- FR-POS-003: The service shall expose `GET /positions/{accountId}` and return positions for the specified account.
- FR-POS-004: The service shall expose `GET /positions/` and return all positions.
- FR-POS-005: The service shall expose health endpoints `GET /health/ready` and `GET /health/alive`.
- FR-POS-006: Trade payload shape shall remain contract-compatible with current consumers (`id`, `accountId`, `security`, `side`, `state`, `quantity`, `created`, `updated`).
- FR-POS-007: Position payload shape shall remain contract-compatible with current consumers (`accountId`, `security`, `quantity`, `updated`).
- FR-POS-008: Data shall be sourced from baseline database tables (`Trades`, `Positions`) without schema change.

## Out Of Scope

- No event-processing ownership changes in this phase.
- No schema redesign in this phase.
- No endpoint path redesign in this phase.
