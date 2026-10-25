---
title: "State 014: FDC3 Intent Interoperability on C3"
pagination_prev: null
pagination_next: null
---

# State 014 Learning Guide

<!-- Generated from specs/014-fdc3-intent-interoperability/learning-contract.json; edit the source. -->

## Pass intent between applications without executing a trade

Copying a ticker between trading, charting and news applications breaks the user’s workflow. This chapter is for developers building desktop interoperability: pass instrument context and request a ticket through Sail, while preserving the distinction between preparing an action and executing it.

[How to learn with TraderX states](/docs/learning/how-to-learn)

**Maturity:** implemented. Run the exercises in a disposable local environment; use the quickstart for setup and cleanup.

### Starting point

C3 supports trading within TraderX; users still copy instrument context between applications.

Entry route: **combined**. Bring the knowledge from every declared predecessor.

#### From 012-platform-convergence-c3

[Predecessor guide](/docs/learning/state-012-platform-convergence-c3)

- **Carry forward:** Treat C3 as a combined platform and functional checkpoint for subsequent branches.
- **Why move:** C3 supports trading within TraderX; users still copy instrument context between applications.
- **Add or revise:** Add FDC3 context and intent handling through Sail so another application can open a prefilled ticket.
- **Evidence to collect:** The selected instrument travels between applications and the requested ticket opens. The user must still decide whether to submit; interop success is not execution evidence. Ticket navigation must not silently book a trade. Widget-specific symbol translation is separate from the canonical fdc3.instrument payload.
- **Objectives:** `trace-increment`, `interpret-evidence`

| Before | After |
| --- | --- |
| C3 supports trading within TraderX; users still copy instrument context between applications. | Add FDC3 context and intent handling through Sail so another application can open a prefilled ticket. |

### Concepts before tools

- Context describes a shared entity such as an instrument. An intent requests an action. Opening a ticket is neither submitting an order nor booking a trade.

**Runtime prerequisites:** Use the state quickstart for tool versions, generation, start and stop commands. Run one local state at a time because ports and generated output directories are shared.

### Learning objectives

- **trace-increment:** Trace an FDC3 intent and instrument context into a prefilled ticket, and verify that opening it creates no order or trade.
- **interpret-evidence:** Explain the evidence boundary: Ticket navigation must not silently book a trade. Widget-specific symbol translation is separate from the canonical fdc3.instrument payload.

### Guided walkthrough

#### 1. observe (available)

Objectives: `trace-increment`.

Follow the quickstart with --with-sail. Open Sail at http://localhost:8090/html/ and use Create Order Ticket or Create Trade Ticket in tab One. Confirm the matching TraderX ticket opens with the selected ticker. Change the TraderX blotter ticker and inspect chart/news context updates.

**Expected observation and meaning:** The selected instrument travels between applications and the requested ticket opens. The user must still decide whether to submit; interop success is not execution evidence.

Supporting material: [quickstart](/specs/fdc3-intent-interoperability/quickstart) · [architecture](/specs/fdc3-intent-interoperability/system/architecture) · [runtime-topology](/specs/fdc3-intent-interoperability/system/runtime-topology).

#### 2. challenge (available)

Objectives: `interpret-evidence`.

Before submitting anything, compare orders and trades with their prior values. Check that opening a ticket created neither. Inspect the canonical bare ticker payload and the Sail-side exchange qualification used by the chart widget.

**Expected observation and meaning:** Ticket navigation must not silently book a trade. Widget-specific symbol translation is separate from the canonical fdc3.instrument payload.

Supporting material: [spec](/specs/fdc3-intent-interoperability/spec) · [contract-delta](/specs/fdc3-intent-interoperability/contracts/contract-delta).

### Demonstrate your understanding

**Question (`trace-increment`, `interpret-evidence`):** What does a successful Create Trade Ticket intent establish?

**Assessment guidance:** It establishes dispatch and ticket preparation with the expected context. Only a later submission and booking evidence establish a trade; neither proves payment or settlement.

### Scope and limitations

- Ticket navigation must not silently book a trade. Widget-specific symbol translation is separate from the canonical fdc3.instrument payload.
- This is an educational local demonstration. Passing its checks does not establish production readiness, financial settlement, or correctness under every failure mode.


## Position In Learning Graph

- Previous state(s): [012-platform-convergence-c3](/docs/learning/state-012-platform-convergence-c3)
- Dotted-line parent(s): none
- Next state(s): none

## Convergence Metadata

- Convergence state: `no`
- Convergence level: `none`
- Lineage role: `canonical`
- Nearest previous convergence: `none`
- Nearest next convergence: `none`

## Rendered Code

- Generated branch: [code/generated-state-014-fdc3-intent-interoperability](https://github.com/finos/traderX/tree/code/generated-state-014-fdc3-intent-interoperability)
- Authoring branch (spec source): [main](https://github.com/finos/traderX/tree/main)

## Code Comparison With Previous State

- Compare against `012-platform-convergence-c3`: [code/generated-state-012-platform-convergence-c3...code/generated-state-014-fdc3-intent-interoperability](https://github.com/finos/traderX/compare/code%2Fgenerated-state-012-platform-convergence-c3...code%2Fgenerated-state-014-fdc3-intent-interoperability)

## Plain-English Code Delta

- **Added:** Orders, trades and positions start on **All tickers**. Each blotter has a labelled, keyboard-accessible **Filter on selected ticker** control and a status showing its effective ticker (or no ticker selected).
- **Added:** Ticker mode stays local: selecting securities still shares FDC3 context with charts/tickets, turning filtering off restores all account rows, and opting back in uses the latest selection. Account changes and tab switches preserve modes; new windows default to All tickers even with retained context.
- **Added:** Account selection propagates independently through `fdc3.account`. Live order updates use the configured event transport, not FDC3; snapshot reconciliation protects creates/fills/cancellations and reconnect refreshes missed data.
- **Added:** Empty or invalid instrument messages retain the last valid selection; this state defines no clear-instrument message. Before any selection, an opted-in blotter shows all tickers and explains why.
- **Added:** FDC3 interop adapter in TraderX frontend for DesktopAgent integration.
- **Added:** Outbound `fdc3.instrument` context publishing when a user selects a ticker-bearing row in trade/order/position views.
- **Added:** Inbound `fdc3.instrument` context handling that retains shared selection for optional blotter filters and ticket defaults.
- **Added:** Standard intent handling for `ViewOrders` (orders view routing without implicit filter opt-in).

## Run This State

```bash
./scripts/start-state-014-fdc3-intent-interoperability-generated.sh
```

## Canonical Spec Links

- State spec pack: [/specs/fdc3-intent-interoperability](/specs/fdc3-intent-interoperability)
- Architecture: [/specs/fdc3-intent-interoperability/system/architecture](/specs/fdc3-intent-interoperability/system/architecture)
- Flows / topology: [/specs/fdc3-intent-interoperability/system/runtime-topology](/specs/fdc3-intent-interoperability/system/runtime-topology)
- Research: [link](/specs/fdc3-intent-interoperability/research)
- Data model: [link](/specs/fdc3-intent-interoperability/data-model)
- Quickstart: [link](/specs/fdc3-intent-interoperability/quickstart)

