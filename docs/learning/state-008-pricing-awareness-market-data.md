---
title: "State 008: Pricing Awareness and Market Data Streaming"
pagination_prev: null
pagination_next: null
---

# State 008 Learning Guide

<!-- Generated from specs/008-pricing-awareness-market-data/learning-contract.json; edit the source. -->

## Distinguish a market observation from a trade

A trader needs market context before making a decision, but a changing number on a screen can be misleading. For developers extending the application’s domain, follow a synthetic quote from publisher to UI and distinguish a fresh observation from a guaranteed execution price.

[How to learn with TraderX states](/docs/learning/how-to-learn) · [Structured lesson JSON](/learning/contracts/008-pricing-awareness-market-data.json)

**Maturity:** implemented. Run the exercises in a disposable local environment; use the quickstart for setup and cleanup.

### Starting point

The observable application books trades without a live pricing context.

Entry route: **combined**. Bring the knowledge from every declared predecessor.

#### From 007-observability-lgtm-compose

[Predecessor guide](/docs/learning/state-007-observability-lgtm-compose)

- **Carry forward:** Add LGTM telemetry to connect a user action with logs, metrics and traces.
- **Why move:** The observable application books trades without a live pricing context.
- **Add or revise:** Stream simulated market data and use price awareness while retaining the booking workflow.
- **Evidence to collect:** Price updates are independent events. A displayed quote supplies context; it does not establish that a trade executed at that price. A retained value can be stale. This synthetic publisher demonstrates propagation, not the quality or availability of a real market feed.
- **Objectives:** `trace-increment`, `interpret-evidence`

| Before | After |
| --- | --- |
| The observable application books trades without a live pricing context. | Stream simulated market data and use price awareness while retaining the booking workflow. |

### Concepts before tools

- A quote is an observation with a timestamp, not an execution promise. A stream can become stale even while the last price remains visible.

**Runtime prerequisites:** Use the state quickstart for tool versions, generation, start and stop commands. Run one local state at a time because ports and generated output directories are shared.

### Learning objectives

- **trace-increment:** Trace two quote updates from the synthetic publisher to the UI and distinguish them from a trade execution record.
- **interpret-evidence:** Explain the evidence boundary: A retained value can be stale. This synthetic publisher demonstrates propagation, not the quality or availability of a real market feed.

### Guided walkthrough

#### 1. observe (available)

Objectives: `trace-increment`.

Start this state and run both the state and messaging smoke commands from the quickstart. Select one ticker in the UI, record two successive displayed prices and their timing, and trace the price-publisher route through NATS to the UI.

**Expected observation and meaning:** Price updates are independent events. A displayed quote supplies context; it does not establish that a trade executed at that price.

Supporting material: [quickstart](/specs/pricing-awareness-market-data/quickstart) · [architecture](/specs/pricing-awareness-market-data/system/architecture) · [runtime-topology](/specs/pricing-awareness-market-data/system/runtime-topology).

#### 2. challenge (available)

Objectives: `interpret-evidence`.

Pause or stop only the price-publisher in the disposable local stack and observe whether the last price remains visible. Resume it and compare update timing. Use telemetry to distinguish stale data from a quiet market.

**Expected observation and meaning:** A retained value can be stale. This synthetic publisher demonstrates propagation, not the quality or availability of a real market feed.

Supporting material: [spec](/specs/pricing-awareness-market-data/spec) · [contract-delta](/specs/pricing-awareness-market-data/contracts/contract-delta).

### Demonstrate your understanding

**Question (`trace-increment`, `interpret-evidence`):** What additional evidence would you require before treating a displayed quote as an execution price?

**Assessment guidance:** A distinct execution record with price and identity. Explain the quote timestamp and the synthetic feed limitation.

### Work with a learning partner

Use the [learning-partner protocol](/docs/learning/how-to-learn#learn-with-an-agent) with a human or an agent. Ask for a prediction before running the exercise, offer one hint at a time, and discuss the assessment guidance after the learner has attempted an explanation.

**Objectives:** `trace-increment`, `interpret-evidence`.

**Check the starting point:** What distinguishes a quote from a record of a trade execution?

**Ask before the experiment:** Predict what you might see if the publisher stops while the UI retains its last price.

**Hints, in order:**

1. Record update timing as well as the displayed number.
2. Follow the publisher-to-UI route and compare a quote with a separate execution record.

**Misconception to probe (not a fact):** A visible quote is necessarily fresh or guarantees an execution at that price.

**Evidence to ask the learner for:** Ask for two timed quote observations, the pause/resume observation and an explanation of synthetic data and execution boundaries.

### Scope and limitations

- A retained value can be stale. This synthetic publisher demonstrates propagation, not the quality or availability of a real market feed.
- This is an educational local demonstration. Passing its checks does not establish production readiness, financial settlement, or correctness under every failure mode.


## Position In Learning Graph

- Previous state(s): [007-observability-lgtm-compose](/docs/learning/state-007-observability-lgtm-compose)
- Dotted-line parent(s): none
- Next state(s): [009-order-management-matcher](/docs/learning/state-009-order-management-matcher)

## Convergence Metadata

- Convergence state: `no`
- Convergence level: `none`
- Lineage role: `canonical`
- Nearest previous convergence: `none`
- Nearest next convergence: `none`

## Rendered Code

- Generated branch: [code/generated-state-008-pricing-awareness-market-data](https://github.com/finos/traderX/tree/code/generated-state-008-pricing-awareness-market-data)
- Authoring branch (spec source): [main](https://github.com/finos/traderX/tree/main)

## Code Comparison With Previous State

- Compare against `007-observability-lgtm-compose`: [code/generated-state-007-observability-lgtm-compose...code/generated-state-008-pricing-awareness-market-data](https://github.com/finos/traderX/compare/code%2Fgenerated-state-007-observability-lgtm-compose...code%2Fgenerated-state-008-pricing-awareness-market-data)

## Plain-English Code Delta

- **Added:** Trade execution pricing (`trade.price`) with 3-decimal precision.
- **Added:** Position pre-aggregated volume-weighted average cost basis (`position.averageCostBasis`).
- **Added:** Market price stream topics (`pricing.<TICKER>`) from a new `price-publisher` component.
- **Added:** Startup-assigned per-ticker volatility band profile for synthetic pricing bounds (20% @ ±4%, 60% @ ±2%, 20% strict open/close).
- **Added:** UI valuation fields: market price, position value, unrealized P&L, portfolio totals.
- **Added:** Position blotter `OPEN` column and directional market marker (`▲/▼/■`) against open price.
- **Added:** Conditional valuation highlighting in position blotter for market-price/open and value-vs-cost comparisons.
- **Added:** Trade ticket selected-security live price stream subscription from `pricing.<TICKER>`.

## Run This State

```bash
./scripts/start-state-008-pricing-awareness-market-data-generated.sh
```

## Canonical Spec Links

- State spec pack: [/specs/pricing-awareness-market-data](/specs/pricing-awareness-market-data)
- Architecture: [/specs/pricing-awareness-market-data/system/architecture](/specs/pricing-awareness-market-data/system/architecture)
- Flows / topology: [/specs/pricing-awareness-market-data/system/runtime-topology](/specs/pricing-awareness-market-data/system/runtime-topology)
- Research: [link](/specs/pricing-awareness-market-data/research)
- Data model: [link](/specs/pricing-awareness-market-data/data-model)
- Quickstart: [link](/specs/pricing-awareness-market-data/quickstart)

