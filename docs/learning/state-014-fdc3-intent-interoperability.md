---
title: "State 014: FDC3 Intent Interoperability on C3"
---

# State 014 Learning Guide

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

