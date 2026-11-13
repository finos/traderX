---
title: "State 018: FalkorDB Portfolio Look-Through"
pagination_prev: null
pagination_next: null
---

# State 018 Learning Guide

<!-- Generated from specs/018-falkordb-lookthrough/learning-contract.json; edit the source. -->

## Compare a graph read model with recursive SQL

For developers extending a trading application, trace indirect economic exposure and verify identical business answers before comparing storage implementations.

[How to learn with TraderX states](/docs/learning/how-to-learn) · [Structured lesson JSON](/learning/contracts/018-falkordb-lookthrough.json)

**Maturity:** implemented. Run the exercises in a disposable local environment; use the quickstart for setup and cleanup.

### Starting point

Understand C2 accounts, positions, pricing and asynchronous trade booking.

Entry route: **combined**. Bring the knowledge from every declared predecessor.

#### From 017-portfolio-lookthrough

[Predecessor guide](/docs/learning/state-017-portfolio-lookthrough)

- **Carry forward:** Keep transactional positions and the C2 trading workflow.
- **Why move:** Direct holdings hide concentration through funds and related issuers.
- **Add or revise:** Add weighted look-through traversal with visible evidence and source freshness.
- **Evidence to collect:** Known synthetic portfolio shows 2% direct and 12% indirect exposure; both engines must agree after source edits.
- **Objectives:** `calculate`, `verify`

| Before | After |
| --- | --- |
| Positions show direct security holdings. | Corporate exposure includes nested funds and issuer groups, with contributing paths. |

### Concepts before tools

- A fund holding is a weighted economic allocation. Corporate-parent links group issuers. Separate allocation paths contribute separately to exposure.

**Runtime prerequisites:** Docker Compose and the state quickstart prerequisites. Use one runtime at a time and disposable test databases.

### Learning objectives

- **calculate:** Reconcile the 14% portfolio exposure with its direct and indirect allocations.
- **verify:** Compare source revisions and verify changed positions before interpreting latency results.

### Guided walkthrough

#### 1. observe (available)

Objectives: `calculate`.

Start this state and open /exposure/. Select account 70000 and target Z0G; expand and reconcile both paths.

**Expected observation and meaning:** 2% direct plus 12% through funds equals 14%, at fixed USD snapshot marks.

Supporting material: [quickstart](/specs/falkordb-lookthrough/quickstart) · [data-model](/specs/falkordb-lookthrough/data-model).

#### 2. challenge (available)

Objectives: `verify`.

Change the Z0S quantity from 20 to 40 using the quickstart SQL workflow, wait for a new revision, and calculate again. Restore the quantity after recording the result.

**Expected observation and meaning:** Exposure changes to 16000/102000; both implementations agree. A changed valuation timestamp must not be inferred from a position-only edit.

Supporting material: [spec](/specs/falkordb-lookthrough/spec) · [contract-delta](/specs/falkordb-lookthrough/contracts/contract-delta).

### Demonstrate your understanding

**Question (`calculate`, `verify`):** Why does doubling the direct position change the portfolio denominator as well as its target exposure?

**Assessment guidance:** Compute the changed portfolio value and contributions separately, and compare identical source revisions before comparing database latency.

### Work with a learning partner

Use the [learning-partner protocol](/docs/learning/how-to-learn#learn-with-an-agent) with a human or an agent. Ask for a prediction before running the exercise, offer one hint at a time, and discuss the assessment guidance after the learner has attempted an explanation.

**Objectives:** `calculate`, `verify`.

**Check the starting point:** Which allocation weights multiply along a fund path?

**Ask before the experiment:** Predict total exposure after increasing Z0S quantity from 20 to 40.

**Hints, in order:**

1. Start with the $100,000 portfolio and $14,000 exposure.
2. The extra 20 units add $2,000 to both values.

**Misconception to probe (not a fact):** Doubling one holding doubles the entire exposure percentage.

**Evidence to ask the learner for:** Show the source position, projection revision, total portfolio value and contributing paths.

### Scope and limitations

- Current-snapshot long-only USD demo with fixed marks; no historical as-of queries or derivative valuation.
- Full snapshot rebuild is a demonstrable reconciliation strategy, not a production CDC or multi-replica design.


## Position In Learning Graph

- Previous state(s): [017-portfolio-lookthrough](/docs/learning/state-017-portfolio-lookthrough)
- Dotted-line parent(s): none
- Next state(s): none

## Convergence Metadata

- Convergence state: `no`
- Convergence level: `none`
- Lineage role: `optional`
- Nearest previous convergence: `none`
- Nearest next convergence: `none`

## Rendered Code

- Generated branch: [code/generated-state-018-falkordb-lookthrough](https://github.com/finos/traderX/tree/code/generated-state-018-falkordb-lookthrough)
- Authoring branch (spec source): [main](https://github.com/finos/traderX/tree/main)

## Code Comparison With Previous State

- Compare against `017-portfolio-lookthrough`: [code/generated-state-017-portfolio-lookthrough...code/generated-state-018-falkordb-lookthrough](https://github.com/finos/traderX/compare/code%2Fgenerated-state-017-portfolio-lookthrough...code%2Fgenerated-state-018-falkordb-lookthrough)

## Plain-English Code Delta

- No functional delta summary is currently available in this state pack.

## Run This State

```bash
./scripts/start-state-018-falkordb-lookthrough-generated.sh
```

## Canonical Spec Links

- State spec pack: [/specs/falkordb-lookthrough](/specs/falkordb-lookthrough)
- Architecture: [/specs/falkordb-lookthrough/system/architecture](/specs/falkordb-lookthrough/system/architecture)
- Flows / topology: [/specs/falkordb-lookthrough/system/runtime-topology](/specs/falkordb-lookthrough/system/runtime-topology)
- Research: [link](/specs/falkordb-lookthrough/research)
- Data model: [link](/specs/falkordb-lookthrough/data-model)
- Quickstart: [link](/specs/falkordb-lookthrough/quickstart)

