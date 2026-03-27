# Trade-Processor Functional Requirements

## Scope

Define baseline functional behavior for the next pure-generated cutover target: `trade-processor`.

## Functional Requirements

- FR-TP-001: The service shall subscribe to trade-feed topic `/trades` and process inbound `TradeOrder` messages.
- FR-TP-002: The service shall persist each processed order as a `Trade` record with a generated unique trade id.
- FR-TP-003: The service shall transition persisted trade state through `New` -> `Processing` -> `Settled` in baseline flow.
- FR-TP-004: The service shall create or update the account/security `Position` record based on order side and quantity.
- FR-TP-005: `Buy` orders shall increment position quantity; `Sell` orders shall decrement position quantity.
- FR-TP-006: After persistence, the service shall publish updated trade and position messages to account-scoped topics:
  - `/accounts/{accountId}/trades`
  - `/accounts/{accountId}/positions`
- FR-TP-007: The service shall expose `POST /tradeservice/order` for direct local processing compatibility.
- FR-TP-008: `POST /tradeservice/order` shall return a `TradeBookingResult` payload containing `trade` and `position`.
- FR-TP-009: The service shall expose docs root endpoint `GET /` redirecting to Swagger UI.
- FR-TP-010: Payload field names for orders, trades, and positions shall remain backward compatible with current TraderX consumers.

## Out Of Scope

- No change to trade matching/pricing logic (this is not an execution engine).
- No multi-step settlement workflow redesign in this phase.
- No authentication/authorization redesign in this phase.
