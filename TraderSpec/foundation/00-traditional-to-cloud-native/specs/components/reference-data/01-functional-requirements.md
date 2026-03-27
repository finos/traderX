# Reference-Data Functional Requirements

## Scope

Define the baseline functional behavior for the first pure-generated component cutover target: `reference-data`.

## Functional Requirements

- FR-RD-001: The service shall expose `GET /stocks` and return a JSON array of stock records.
- FR-RD-002: Each stock record shall include: `ticker`, `companyName`.
- FR-RD-003: The service shall expose `GET /stocks/{ticker}` and return one stock record for a known ticker.
- FR-RD-004: `GET /stocks/{ticker}` for unknown ticker shall return HTTP `404`.
- FR-RD-005: The service shall expose `GET /health` and return HTTP `200` when operational.
- FR-RD-006: Symbol lookup shall match tickers exactly (case-sensitive baseline behavior).
- FR-RD-007: Returned stock payload shape shall remain backward compatible with `trade-service` and Angular UI consumers.
- FR-RD-008: The service shall load stock symbols from the baseline CSV universe (`s-and-p-500-companies.csv`) rather than a minimal hardcoded seed.

## Out Of Scope

- No write endpoints for stock data in baseline.
- No persistence layer migration in this component phase.
- No auth/authz changes in this phase.
