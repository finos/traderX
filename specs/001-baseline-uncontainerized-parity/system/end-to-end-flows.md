# End-to-End Flows (Spec Kit)

Primary flow source: `docs/flows.md`.

## F1: Load Accounts On Initial UI Load

- UI requests account list from account-service.
- account-service queries database accounts.
- UI renders account selector.

## F2: Bootstrap Trade + Position Blotters

- UI requests trades and positions for selected account from position-service.
- position-service queries database and returns current state.
- UI subscribes to trade-feed account topics for incremental updates.

## F3: Submit Trade Ticket

- UI loads ticker universe from reference-data.
- UI submits trade request to trade-service.
- trade-service validates ticker via reference-data and account via account-service.
- trade-service publishes new trade event to trade-feed.

## F4: Process Trade Events

- trade-processor subscribes to new trade events from trade-feed.
- trade-processor persists new/updated trade records in database.
- trade-processor updates positions in database.
- trade-processor publishes account-scoped trade and position updates through trade-feed.
- UI receives stream updates and refreshes blotters.

## F5: Add/Update Account

- UI submits create/update account command to account-service.
- account-service persists account to database.
- UI receives success/failure response.

## F6: Add/Update Account Users

- UI fetches current account-user mappings from account-service.
- UI searches people via people-service.
- account-service validates user with people-service before mapping.
- account-service persists account-user mapping in database.

## Startup Dependency Flow (Operational)

Order is governed by baseline runtime specs and startup catalog:

`database -> reference-data -> trade-feed -> people-service -> account-service -> position-service -> trade-processor -> trade-service -> web-front-end-angular`
