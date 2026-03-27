# Trade-Service Functional Requirements

## Scope

Define baseline functional behavior for the next pure-generated cutover target: `trade-service`.

## Functional Requirements

- FR-TS-001: The service shall expose `POST /trade/` to accept trade order submissions from the UI.
- FR-TS-002: The service shall validate submitted ticker symbols against `reference-data` (`/stocks/{ticker}`).
- FR-TS-003: The service shall validate submitted account ids against `account-service` (`/account/{id}`).
- FR-TS-004: If ticker validation fails, the service shall reject the trade with HTTP `404`.
- FR-TS-005: If account validation fails, the service shall reject the trade with HTTP `404`.
- FR-TS-006: For valid submissions, the service shall publish the order to trade-feed topic `/trades`.
- FR-TS-007: For valid submissions, the service shall return HTTP `200` with the submitted trade order payload.
- FR-TS-008: The service shall expose `GET /` and redirect to Swagger UI.
- FR-TS-009: Payload compatibility shall include baseline field names used by TraderX clients (`accountId`, compatibility alias `accountID`).

## Out Of Scope

- No trade persistence in this component (handled by trade-processor).
- No pricing or risk validation redesign in this phase.
- No authentication/authorization redesign in this phase.
