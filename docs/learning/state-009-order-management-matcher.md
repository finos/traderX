---
title: "State 009: Order Management and Matcher"
pagination_prev: null
pagination_next: null
---

# State 009 Learning Guide

<!-- Generated from specs/009-order-management-matcher/learning-contract.json; edit the source. -->

## Model an order before it becomes a trade

An intention to buy may remain unfulfilled, fill in pieces, or be canceled. For developers moving beyond immediate trade booking, this chapter introduces the order lifecycle and shows why an order’s requested quantity cannot be treated as an executed position.

[How to learn with TraderX states](/docs/learning/how-to-learn) · [Structured lesson JSON](/learning/contracts/009-order-management-matcher.json)

**Maturity:** implemented. Run the exercises in a disposable local environment; use the quickstart for setup and cleanup.

### Starting point

The pricing state shows quotes and can book trades, but has no persistent pending-order lifecycle.

Entry route: **combined**. Bring the knowledge from every declared predecessor.

#### From 008-pricing-awareness-market-data

[Predecessor guide](/docs/learning/state-008-pricing-awareness-market-data)

- **Carry forward:** Stream simulated market data and use price awareness while retaining the booking workflow.
- **Why move:** The pricing state shows quotes and can book trades, but has no persistent pending-order lifecycle.
- **Add or revise:** Introduce limit orders, matching and fills while keeping orders distinct from executed trades.
- **Evidence to collect:** A resting order is not a booked trade. A qualifying tick can trigger a fill; the matcher policy is a demonstration, not an exchange matching engine. Cancellation of the remainder does not reverse an already booked fill. Large quantities can produce partial fills under the demonstration policy.
- **Objectives:** `trace-increment`, `interpret-evidence`

| Before | After |
| --- | --- |
| The pricing state shows quotes and can book trades, but has no persistent pending-order lifecycle. | Introduce limit orders, matching and fills while keeping orders distinct from executed trades. |

### Concepts before tools

- An order expresses an intention. A fill executes some quantity. A limit caps a buy price or sets a sell floor; partial fills leave a remainder.

**Runtime prerequisites:** Use the state quickstart for tool versions, generation, start and stop commands. Run one local state at a time because ports and generated output directories are shared.

### Learning objectives

- **trace-increment:** Distinguish a resting order, a fill and a booked trade by reconciling their identifiers and quantities.
- **interpret-evidence:** Explain the evidence boundary: Cancellation of the remainder does not reverse an already booked fill. Large quantities can produce partial fills under the demonstration policy.

### Guided walkthrough

#### 1. observe (available)

Objectives: `trace-increment`.

Start this state, choose a ticker with current quotes, and create a small buy limit order below the displayed market. Record its identifier and remaining quantity. Compare the order view with the trade view. Then create an executable small limit order and observe the matcher and resulting fill.

**Expected observation and meaning:** A resting order is not a booked trade. A qualifying tick can trigger a fill; the matcher policy is a demonstration, not an exchange matching engine.

Supporting material: [quickstart](/specs/order-management-matcher/quickstart) · [architecture](/specs/order-management-matcher/system/architecture) · [runtime-topology](/specs/order-management-matcher/system/runtime-topology).

#### 2. challenge (available)

Objectives: `interpret-evidence`.

Create an unfilled order and cancel it. Verify its terminal state and compare trade records before and after cancellation. Inspect the documented partial-fill policy for quantities at or above 1000.

**Expected observation and meaning:** Cancellation of the remainder does not reverse an already booked fill. Large quantities can produce partial fills under the demonstration policy.

Supporting material: [spec](/specs/order-management-matcher/spec) · [contract-delta](/specs/order-management-matcher/contracts/contract-delta).

### Demonstrate your understanding

**Question (`trace-increment`, `interpret-evidence`):** How would you reconcile an order that is partially filled and then canceled?

**Assessment guidance:** Account for filled quantity in executions and positions, and the unfilled remainder in the canceled order. Do not treat the original requested quantity as fully traded.

### Work with a learning partner

Use the [learning-partner protocol](/docs/learning/how-to-learn#learn-with-an-agent) with a human or an agent. Ask for a prediction before running the exercise, offer one hint at a time, and discuss the assessment guidance after the learner has attempted an explanation.

**Objectives:** `trace-increment`, `interpret-evidence`.

**Check the starting point:** How are requested quantity, filled quantity and remaining quantity related?

**Ask before the experiment:** Predict which records should exist for a resting limit order before it receives a qualifying tick.

**Hints, in order:**

1. Start by separating the order identifier from execution identifiers.
2. Reconcile requested quantity with filled quantity and the canceled or still-open remainder.

**Misconception to probe (not a fact):** Creating or canceling an order creates or reverses a trade for the entire requested quantity.

**Evidence to ask the learner for:** Ask for the order lifecycle and quantities plus associated executions/positions, and have the learner explain any partially filled remainder.

### Scope and limitations

- Cancellation of the remainder does not reverse an already booked fill. Large quantities can produce partial fills under the demonstration policy.
- This is an educational local demonstration. Passing its checks does not establish production readiness, financial settlement, or correctness under every failure mode.


## Position In Learning Graph

- Previous state(s): [008-pricing-awareness-market-data](/docs/learning/state-008-pricing-awareness-market-data)
- Dotted-line parent(s): none
- Next state(s): [010-kubernetes-runtime](/docs/learning/state-010-kubernetes-runtime)

## Convergence Metadata

- Convergence state: `yes`
- Convergence level: `C2`
- Lineage role: `canonical`
- Nearest previous convergence: [007-observability-lgtm-compose](/docs/learning/state-007-observability-lgtm-compose)
- Nearest next convergence: [012-platform-convergence-c3](/docs/learning/state-012-platform-convergence-c3)

## Rendered Code

- Generated branch: [code/generated-state-009-order-management-matcher](https://github.com/finos/traderX/tree/code/generated-state-009-order-management-matcher)
- Authoring branch (spec source): [main](https://github.com/finos/traderX/tree/main)

## Code Comparison With Previous State

- Compare against `008-pricing-awareness-market-data`: [code/generated-state-008-pricing-awareness-market-data...code/generated-state-009-order-management-matcher](https://github.com/finos/traderX/compare/code%2Fgenerated-state-008-pricing-awareness-market-data...code%2Fgenerated-state-009-order-management-matcher)

## Plain-English Code Delta

- **Added:** Order domain with lifecycle states (`NEW`, `PARTIALLY_FILLED`, `FILLED`, `CANCELED`, `REJECTED`).
- **Added:** Order matcher component (Java Spring Boot) for evaluating executable orders and publishing fill events.
- **Added:** Order management API surface for create/list/cancel/force-fill workflows.
- **Added:** Database-backed order persistence so active orders survive order-matcher restarts.
- **Added:** Tick-driven auto-fill policy for in-the-money orders:
- **Added:** remaining quantity `< 1000`: fill full remaining quantity
- **Added:** remaining quantity `>= 1000`: fill half (rounded up)
- **Added:** Trader UI order ticket for limit-order creation, separated from market-trade ticket workflow.

## Run This State

```bash
./scripts/start-state-009-order-management-matcher-generated.sh
```

## Canonical Spec Links

- State spec pack: [/specs/order-management-matcher](/specs/order-management-matcher)
- Architecture: [/specs/order-management-matcher/system/architecture](/specs/order-management-matcher/system/architecture)
- Flows / topology: [/specs/order-management-matcher/system/runtime-topology](/specs/order-management-matcher/system/runtime-topology)
- Research: [link](/specs/order-management-matcher/research)
- Data model: [link](/specs/order-management-matcher/data-model)
- Quickstart: [link](/specs/order-management-matcher/quickstart)

