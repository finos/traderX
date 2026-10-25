---
title: "State 001: Simple App - Base Uncontainerized App"
pagination_prev: null
pagination_next: null
---

# State 001 Learning Guide

<!-- Generated from specs/001-baseline-uncontainerized-parity/learning-contract.json; edit the source. -->

## Follow a trade beyond the screen

When a trader clicks Buy, several services must cooperate before the application can show a new holding. This opening chapter is for developers learning the trading domain: follow that small action through the system and learn which records establish that it happened.

[How to learn with TraderX states](/docs/learning/how-to-learn)

**Maturity:** released. Run the exercises in a disposable local environment; use the quickstart for setup and cleanup.

### Starting point

You can read HTTP requests and run local processes, but have not yet traced TraderX.

This is the foundation. It has no predecessor; the entry assumptions above are the starting point.

| Before | After |
| --- | --- |
| You can read HTTP requests and run local processes, but have not yet traced TraderX. | Trace the browser, trade service, event transport, processor, database and position view as one business workflow. |

### Concepts before tools

- A trade records an executed purchase or sale. A position aggregates holdings. Booking records the trade; it does not transfer cash or prove settlement.

**Runtime prerequisites:** Use the state quickstart for tool versions, generation, start and stop commands. Run one local state at a time because ports and generated output directories are shared.

### Learning objectives

- **trace-increment:** Trace one submitted trade from its HTTP request through processing to the persisted trade and changed position.
- **interpret-evidence:** Explain the evidence boundary: A rejected request should not produce a booked trade. If the result is uncertain, query the record before resubmitting; a timeout alone does not prove rejection.

### Guided walkthrough

#### 1. observe (available)

Objectives: `trace-increment`.

Open the local UI printed by the start script. Select an account, record its position for one ticker, and submit a small buy using the trade ticket. Record the trade identifier and compare the trade and position views. Follow F3 and F4 in the flow reference to identify the writer of each result.

**Expected observation and meaning:** The ticket request and downstream processing are separate steps. The trade record and resulting position provide stronger evidence than a successful button click.

Supporting material: [quickstart](/specs/baseline-uncontainerized-parity/quickstart) · [architecture](/specs/baseline-uncontainerized-parity/system/architecture) · [end-to-end-flows](/specs/baseline-uncontainerized-parity/system/end-to-end-flows).

#### 2. challenge (available)

Objectives: `interpret-evidence`.

In the local demo, submit a ticket with a missing required value. Compare the validation response and the blotters with the successful submission; inspect the trade-service contract to identify which boundary rejects it.

**Expected observation and meaning:** A rejected request should not produce a booked trade. If the result is uncertain, query the record before resubmitting; a timeout alone does not prove rejection.

Supporting material: [spec](/specs/baseline-uncontainerized-parity/spec) · [system-requirements](/specs/baseline-uncontainerized-parity/system/system-requirements).

### Demonstrate your understanding

**Question (`trace-increment`, `interpret-evidence`):** Why is a successful HTTP request insufficient evidence that the position changed?

**Assessment guidance:** Name the asynchronous processor and persisted result, then show the matching trade and position. Do not infer cash settlement from either.

### Scope and limitations

- A rejected request should not produce a booked trade. If the result is uncertain, query the record before resubmitting; a timeout alone does not prove rejection.
- This is an educational local demonstration. Passing its checks does not establish production readiness, financial settlement, or correctness under every failure mode.


## Position In Learning Graph

- Previous state(s): none
- Dotted-line parent(s): none
- Next state(s): [002-edge-proxy-uncontainerized](/docs/learning/state-002-edge-proxy-uncontainerized)

## Convergence Metadata

- Convergence state: `no`
- Convergence level: `none`
- Lineage role: `prelude`
- Nearest previous convergence: `none`
- Nearest next convergence: `none`

## Rendered Code

- Generated branch: [code/generated-state-001-baseline-uncontainerized-parity](https://github.com/finos/traderX/tree/code/generated-state-001-baseline-uncontainerized-parity)
- Authoring branch (spec source): [main](https://github.com/finos/traderX/tree/main)

## Code Comparison With Previous State

- No previous-state compare link for this state.

## Plain-English Code Delta

- **Code focus:** Establishes the full baseline service set and Angular UI in a local multi-process runtime.
- **Runtime behavior:** Uses explicit host ports and direct cross-origin service calls.
- **Learning takeaway:** This is the reference implementation all later state diffs are measured against.

## Run This State

```bash
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./scripts/start-base-uncontainerized-generated.sh
```

## Canonical Spec Links

- State spec pack: [/specs/baseline-uncontainerized-parity](/specs/baseline-uncontainerized-parity)
- Architecture: [/specs/baseline-uncontainerized-parity/system/architecture](/specs/baseline-uncontainerized-parity/system/architecture)
- Flows / topology: [/specs/baseline-uncontainerized-parity/system/end-to-end-flows](/specs/baseline-uncontainerized-parity/system/end-to-end-flows)
- Research: [link](/specs/baseline-uncontainerized-parity/research)
- Data model: [link](/specs/baseline-uncontainerized-parity/data-model)
- Quickstart: [link](/specs/baseline-uncontainerized-parity/quickstart)

