---
title: "State 016: FDC3 Post-Trade Cash-Leg Payment Transfer"
---

# State 016 Learning Guide

## Position In Learning Graph

- Previous state(s): [014-fdc3-intent-interoperability](/docs/learning/state-014-fdc3-intent-interoperability)
- Dotted-line parent(s): none
- Next state(s): none

## Convergence Metadata

- Convergence state: `no`
- Convergence level: `none`
- Lineage role: `optional`
- Nearest previous convergence: `none`
- Nearest next convergence: `none`

## Rendered Code

- Generated branch: `n/a`
- Authoring branch (spec source): [main](https://github.com/finos/traderX/tree/main)

## Code Comparison With Previous State

- No previous-state compare link for this state.

## Plain-English Code Delta

- **Added:** The blotter can discharge a trade's outstanding cash obligation: after execution, the payer leg owes the settled currency amount, and `SETTLE (BANKERX)` raises the standard FDC3 `StartPayment` intent with that amount, cash currency, currency pair, debtor/creditor parties and a UUIDv4 UETR — keyed back to the originating trade.
- **Added:** The blotter renders the settlement lifecycle per row: `SETTLING…` while the intent is in flight, then `SETTLED` (`Acsc`) or `REJECTED` (`Rjct`) from an ISO 20022 `pacs.002` status report, correlated strictly by UETR; status reports with an unknown UETR are logged, never applied to a row.
- **Added:** A dependency-free local mock receiver pack (`generation/mock-receiver/`) ships as the default `StartPayment` participant so the request-to-outcome round trip is reproducible offline without the BankerX terminal. In this state the mock simulates the receiver, including its verdict, and does not verify a real payment rail.
- **Added:** An opt-in BankerX reference adapter (via an app-directory URL swap, provider-neutral, no TraderX change) resolves `StartPayment` against the live settlement terminal, where pre-flight compliance (`pacs.008` formability) and the returned `pacs.002` status come from the adapter's verification boundary.
- **Changed:** State 014's behavior is preserved unchanged: with no `StartPayment` participant in the workspace, intent discovery resolves to nothing and the blotter renders the pristine 014 UI with no action column.
- **Changed:** Settlement dispatch and status state is session-scoped in TraderX only (UETR, row correlation, outcome); adding 016 introduces no server-side persistence or schema change to the earlier states.
- **Removed:** None. 016 is an additive overlay on the 014 baseline.
- **Flow Impact:** Trade row → FDC3 `StartPayment` (`fdc3.payment` context, PR #2204 payload) → receiver (mock or BankerX adapter) → `pacs.002`-shaped `synaptic.settlementStatus` broadcast → matching blotter row flips by UETR; duplicate settlement requests on an in-flight or settled row are suppressed.

## Run This State

```bash
./scripts/start-state-016-post-trade-settlement-bankerx-generated.sh
```

## Canonical Spec Links

- State spec pack: [/specs/post-trade-settlement-bankerx](/specs/post-trade-settlement-bankerx)
- Architecture: [/specs/post-trade-settlement-bankerx/system/architecture](/specs/post-trade-settlement-bankerx/system/architecture)
- Flows / topology: [/specs/post-trade-settlement-bankerx/system/system-context](/specs/post-trade-settlement-bankerx/system/system-context)
- Research: [link](/specs/post-trade-settlement-bankerx/research)
- Data model: [link](/specs/post-trade-settlement-bankerx/data-model)
- Quickstart: [link](/specs/post-trade-settlement-bankerx/quickstart)

