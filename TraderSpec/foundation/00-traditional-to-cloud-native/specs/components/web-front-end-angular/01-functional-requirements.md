# Web-Front-End (Angular) Functional Requirements

## Scope

Define baseline functional behavior for the final base-case cutover target: `web-front-end-angular`.

## Functional Requirements

- FR-WEB-001: The UI shall expose the trade workflow screen on `/trade` and default route `/`.
- FR-WEB-002: The UI shall allow users to create a trade ticket with fields: account, ticker, side, quantity.
- FR-WEB-003: The UI shall fetch account data from account-service for account selection.
- FR-WEB-004: The UI shall fetch symbol data from reference-data for ticker selection.
- FR-WEB-005: The UI shall submit trade tickets to trade-service endpoint `/trade/`.
- FR-WEB-006: The UI shall render trade blotter data for selected account using position-service trade APIs.
- FR-WEB-007: The UI shall render position blotter data for selected account using position-service position APIs.
- FR-WEB-008: The UI shall subscribe to trade-feed account topics and live-update blotters for:
  - `/accounts/{accountId}/trades`
  - `/accounts/{accountId}/positions`
- FR-WEB-009: The UI shall preserve baseline validation and error feedback behavior for failed trade submissions.
- FR-WEB-010: The UI shall preserve endpoint/environment wiring for local pre-ingress ports.

## Out Of Scope

- No redesign of UX visual language in this phase.
- No migration away from Angular in this phase.
- No auth/identity UX redesign in this phase.
