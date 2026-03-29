# Account-Service Functional Requirements

## Scope

Define baseline functional behavior for the next pure-generated cutover target: `account-service`.

## Functional Requirements

- FR-AS-001: The service shall expose `GET /account/{id}` and return a single account record by ID.
- FR-AS-002: The service shall expose `GET /account/` and return all accounts.
- FR-AS-003: The service shall expose `POST /account/` and create a new account record.
- FR-AS-004: The service shall expose `PUT /account/` and update an existing account record.
- FR-AS-005: The service shall expose `GET /accountuser/{id}` and return one account-user mapping by ID.
- FR-AS-006: The service shall expose `GET /accountuser/` and return all account-user mappings.
- FR-AS-007: The service shall expose `POST /accountuser/` and create a user-account mapping when the user exists in people-service.
- FR-AS-008: `POST /accountuser/` shall return HTTP `404` when people-service cannot resolve the provided username.
- FR-AS-009: The service shall expose `PUT /accountuser/` and update an existing account-user mapping.
- FR-AS-010: Response payloads shall remain contract-compatible with existing Angular and trade-service consumers.

## Out Of Scope

- No database schema redesign in this phase.
- No identity/authz redesign in this phase.
- No endpoint path refactor in this phase.
