# 07 UI Requirements (Detailed)

## UI-001 Account Selection

The UI must fetch and present available accounts from account-service and allow selecting one active account.

## UI-002 Trade Ticket Form

The trade ticket must include:

- readonly selected account display
- symbol lookup with typeahead over reference-data symbols
- side selector (`Buy|Sell`)
- quantity input

Validation:

- symbol required
- quantity > 0

## UI-003 Trade Submission

Create action sends ticket payload to trade-service and surfaces response/error state.

## UI-004 Trade Blotter

For selected account:

- initial trade list loaded from position-service `/trades/{accountId}`
- live updates from trade-feed topic `/accounts/{accountId}/trades`

## UI-005 Position Blotter

For selected account:

- initial positions loaded from position-service `/positions/{accountId}`
- live updates from trade-feed topic `/accounts/{accountId}/positions`

## UI-006 Environment Contract

UI endpoint config must be generated from service endpoint specification, not hardcoded per app.

## UI-007 Accessibility and UX Baseline

- keyboard-navigable primary actions
- readable table headings and form labels
- clear error feedback for failed calls
