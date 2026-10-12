# Functional Delta — 016 vs 014

What state 016 changes relative to the pristine 014 FDC3 baseline. This state
is **experimental**: it demonstrates the cash leg of an already executed trade
(currency payment transfer), not securities DvP/PvP, and no published
generated-code branch exists for it yet.

## Added

- The blotter can discharge a trade's outstanding cash obligation: after execution, the payer leg owes the settled currency amount, and `SETTLE (BANKERX)` raises the standard FDC3 `StartPayment` intent with that amount, cash currency, currency pair, debtor/creditor parties and a UUIDv4 UETR — keyed back to the originating trade.
- The blotter renders the settlement lifecycle per row: `SETTLING…` while the intent is in flight, then `SETTLED` (`Acsc`) or `REJECTED` (`Rjct`) from an ISO 20022 `pacs.002` status report, correlated strictly by UETR; status reports with an unknown UETR are logged, never applied to a row.
- A dependency-free local mock receiver pack (`generation/mock-receiver/`) ships as the default `StartPayment` participant so the request-to-outcome round trip is reproducible offline without the BankerX terminal. In this state the mock simulates the receiver, including its verdict, and does not verify a real payment rail.
- An opt-in BankerX reference adapter (via an app-directory URL swap, provider-neutral, no TraderX change) resolves `StartPayment` against the live settlement terminal, where pre-flight compliance (`pacs.008` formability) and the returned `pacs.002` status come from the adapter's verification boundary.

## Changed

- State 014's behavior is preserved unchanged: with no `StartPayment` participant in the workspace, intent discovery resolves to nothing and the blotter renders the pristine 014 UI with no action column.
- Settlement dispatch and status state is session-scoped in TraderX only (UETR, row correlation, outcome); adding 016 introduces no server-side persistence or schema change to the earlier states.

## Removed

- None. 016 is an additive overlay on the 014 baseline.

## Flow Impact

- Trade row → FDC3 `StartPayment` (`fdc3.payment` context, PR #2204 payload) → receiver (mock or BankerX adapter) → `pacs.002`-shaped `synaptic.settlementStatus` broadcast → matching blotter row flips by UETR; duplicate settlement requests on an in-flight or settled row are suppressed.