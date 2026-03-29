# 05 Functional Requirements (Detailed)

This file expands baseline FRs into generation-grade requirements with concrete behavior and acceptance checks.

## FR-001 Account Lifecycle

The platform must support:

- create account
- list accounts
- create account-user mapping
- list account-user mappings

Acceptance:

- account-service endpoints for `/account/` and `/accountuser/` support create/list flows.
- UI can display accounts and assign users.

## FR-002 Trade Capture and Validation

The platform must accept trade orders with:

- `accountId`
- `security`
- `side` (`Buy|Sell`)
- `quantity`

Validation:

- `security` exists in reference-data service.
- `accountId` exists in account-service.

Acceptance:

- valid trades are published to trade-feed topic `/trades`.
- invalid account/ticker returns client-visible validation error.

## FR-003 Trade Processing and Position Updates

On each accepted trade:

- trade-processor consumes from `/trades`
- persists/updates trade state lifecycle
- recalculates positions
- publishes updates to:
  - `/accounts/{accountId}/trades`
  - `/accounts/{accountId}/positions`

Acceptance:

- trade blotter and position blotter updates are visible for subscribed account.

## FR-004 Read APIs for Trades and Positions

The platform must expose read APIs to retrieve:

- trades by account
- all trades
- positions by account
- all positions

Acceptance:

- position-service endpoints return data used by UI blotters.

## FR-005 Reference Data and People Directory Access

The platform must expose:

- stock lookup/list via reference-data
- person lookup/validation via people-service

Acceptance:

- trade ticket symbol search uses reference-data.
- account-user assignment uses people lookup results.

## FR-006 Primary UI Workflow

Angular UI must support end-to-end trading workflow:

1. load accounts
2. choose account
3. create trade from ticket form
4. show live trade and position updates for selected account

Acceptance:

- trade ticket create action calls trade-service create endpoint.
- blotters load initial data and continue streaming updates from trade-feed.

## FR-007 Health and Basic Operability

Core services must expose health/readiness endpoints and boot with documented env defaults.

Acceptance:

- health checks return success when stack is healthy.
