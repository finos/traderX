---
title: "State 019: TraderX Security Lab (Planned)"
pagination_prev: null
pagination_next: null
---

# State 019 Learning Guide

<!-- Generated from specs/019-traderx-security-lab/learning-contract.json; edit the source. -->

## Measure security boundaries and residual authority

Help developers and security practitioners explain what controls prevent, detect and still permit in a trading application. Learn in phases before comparing runtime products.

[How to learn with TraderX states](/docs/learning/how-to-learn) · [Structured lesson JSON](/learning/contracts/019-traderx-security-lab.json)

**Maturity:** planned. Intended lesson: runtime exercises are unavailable.

### Starting point

C3 normal trading and its Kubernetes runtime are understood; no production data is used.

Entry route: **combined**. Bring the knowledge from every declared predecessor.

#### From 012-platform-convergence-c3

[Predecessor guide](/docs/learning/state-012-platform-convergence-c3)

- **Carry forward:** Trading, Kubernetes and observability.
- **Why move:** A working application does not yet explain its security boundaries.
- **Add or revise:** Add staged controls, bounded experiments and independent outcome evidence.
- **Evidence to collect:** Positive trading plus attributable negative checks and residual-authority outcomes in the same pinned deployment.
- **Objectives:** `attribute-control`, `measure-residual`, `reproduce-recover`

| Before | After |
| --- | --- |
| C3 demonstrates normal trading. | Target: learners can reproduce and explain layered security and residual risk; integrated acceptance is pending. |

### Concepts before tools

- A reachable destination is not unlimited database authority; scoped service authority is not end-user business authorization.
- An alert or killed process does not prove that impact was prevented.

**Runtime prerequisites:** The integrated state is planned. Prototype onboarding is explicitly limited to its verified host and fixture scope; run only one full cluster at a time.

### Learning objectives

- **attribute-control:** Explain which security layer intervened using correlated decisions and independent state evidence.
- **measure-residual:** Distinguish denied out-of-grant operations from residual misuse of legitimate service authority, then compare detection with prevention.
- **reproduce-recover:** Reproduce a bounded experiment, restore synthetic data and verify that legitimate trading continues within a measured resource budget.

### Guided walkthrough

#### 1. control-boundaries (unavailable)

Objectives: `attribute-control`, `measure-residual`, `reproduce-recover`.

Planned integrated walkthrough: predict a decision, run positive and negative controls, inspect effects, compare runtime modes and reset. Prototype checkpoint evidence is available separately.

**Expected observation and meaning:** Attribute each decision and resulting state; do not infer prevention from an alert or claim a fixture is integrated.

Supporting material: [quickstart](/specs/traderx-security-lab/quickstart) · [tasks](/specs/traderx-security-lab/tasks) · [spec](/specs/traderx-security-lab/spec).

### Demonstrate your understanding

**Question (`attribute-control`, `measure-residual`, `reproduce-recover`):** A service talks to its allowed database and a runtime alert fires. What proves prevention and successful recovery?

**Assessment guidance:** Inspect independent canary and downstream effects after settling, compare the same inputs across profiles, reset and rerun positive trading; record resource costs and limitations.

### Work with a learning partner

Use the [learning-partner protocol](/docs/learning/how-to-learn#learn-with-an-agent) with a human or an agent. Ask for a prediction before running the exercise, offer one hint at a time, and discuss the assessment guidance after the learner has attempted an explanation.

**Objectives:** `attribute-control`, `measure-residual`, `reproduce-recover`.

**Check the starting point:** Which identity and authority does each boundary actually enforce?

**Ask before the experiment:** Predict whether a within-grant write by a compromised service will be distinguishable from normal work.

**Hints, in order:**

1. Follow the identity from the user through the process and database role.
2. Inspect final state independently; an alert is a separate observation.

**Misconception to probe (not a fact):** Strong networking or a runtime alert guarantees that all business-unauthorized writes are prevented.

**Evidence to ask the learner for:** Pinned configuration, correlated decisions, independent before/after outcomes, reset evidence and continued trading.

### Scope and limitations

- Planned generated state; current evidence covers individual checkpoints and candidate integrations only.
- CVE/OSERA is optional and planned; CALM is a separate successor. Local checks are not compliance certification.


## Position In Learning Graph

- Previous state(s): [012-platform-convergence-c3](/docs/learning/state-012-platform-convergence-c3)
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

- No functional delta summary is currently available in this state pack.

## Run This State

```bash
# Planned state: runtime exercise unavailable
```

## Canonical Spec Links

- State spec pack: [/specs/traderx-security-lab](/specs/traderx-security-lab)
- Architecture: [/specs/traderx-security-lab/system/architecture](/specs/traderx-security-lab/system/architecture)
- Flows / topology: [/specs/traderx-security-lab/system/system-context](/specs/traderx-security-lab/system/system-context)
- Research: [link](/specs/traderx-security-lab/research)
- Data model: [link](/specs/traderx-security-lab/data-model)
- Quickstart: [link](/specs/traderx-security-lab/quickstart)

