# Smoke Tests: 016-post-trade-settlement-bankerx

Child state of `014-fdc3-intent-interoperability`. The 014 smoke suite
(`specs/014-*/tests/smoke/README.md`) remains fully applicable to generated 016
output — this pack adds only the post-trade settlement deltas:

## Lifecycle smoke script (dependency-free)

```bash
node specs/016-post-trade-settlement-bankerx/tests/smoke/lifecycle-mock-receiver.test.mjs
```

Runs the SAME provider-neutral lifecycle module the mock receiver page uses
(`specs/016-*/generation/mock-receiver/payment-lifecycle.mjs`), so demo and test
share one implementation. Gates:

- Valid `fdc3.paymentContext` passes CBPR+ field-level validation.
- UETR is RFC 4122 UUIDv4; wrong context type rejected.
- Malformed payloads rejected field-by-field with honest reasons.
- Happy path settles `Acsc` and builds the `synaptic.settlementStatus` broadcast.
- Duplicate dispatch replays the FIRST outcome (exactly one settlement record per UETR).
- Honest rejection (`Rjct`) is recorded with its reason, never silently dropped.
- Rail failure falls back to `Pndg` — never a fabricated `Acsc`.
- Status context carries the UETR correlation fields.

## Generated-runtime checks (when the 016 state branch is generated)

- Generated 014 → generated 016 diff shows exactly one new lesson: post-trade settlement.
- Base TraderX (no post-trade participant in the workspace) renders the pristine
  014 blotter — no `SETTLE` action column.
- With the mock receiver (or BankerX) in the workspace, `findIntent('StartPayment')`
  resolves and the `SETTLE (BANKERX)` action appears on trade rows.
- Dispatch → receiver renders the context → `synaptic.settlementStatus` broadcast →
  row flips `SETTLING…` → `SETTLED` / `REJECTED`, correlated by UETR.
- Duplicate click while a settlement is in flight is suppressed with a status message.
- Dispatch failure reverts the row cleanly (no stuck `SETTLING…` state).
- Without an FDC3 agent the blotter stays fully functional (014 baseline).