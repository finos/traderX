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

- **Added:** FDC3 interop adapter in TraderX frontend for DesktopAgent integration.
- **Added:** Outbound `fdc3.instrument` context publishing when a user selects a ticker-bearing row in trade/order/position views.
- **Added:** Inbound `fdc3.instrument` context handling that updates ticker-focused UI state (filters and ticket defaults).
- **Added:** Outbound and inbound `traderx.account` context handling that synchronizes selected account state across TraderX windows.
- **Added:** Standard intent handling for `ViewOrders` (instrument-scoped orders view routing).
- **Added:** Outbound standard intent triggers for `ViewChart` and `ViewQuote` from explicit TraderX UI actions.
- **Added:** Custom inbound intents `TraderX.CreateTradeTicket` and `TraderX.CreateOrderTicket` that open the respective ticket UI with preselected ticker context.
- **Added:** Local Sail sidecar runtime profile for interop demos.

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

