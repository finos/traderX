---
title: "State 019: TraderX Security Lab (Planned)"
pagination_prev: null
pagination_next: null
---

# State 019 Learning Guide

<!-- Generated from specs/019-traderx-security-lab/learning-contract.json; edit the source. -->

## Measure security boundaries and residual authority

Help developers and security practitioners explain what controls prevent, detect and still permit in a trading application, then measure what those protections cost. Learn in phases before comparing runtime products or platform alternatives.

[How to learn with TraderX states](/docs/learning/how-to-learn) · [Structured lesson JSON](/learning/contracts/019-traderx-security-lab.json)

**Maturity:** planned. Intended lesson: runtime exercises are unavailable.

### Starting point

C3 normal trading and its Kubernetes runtime are understood; no production data is used.

Entry route: **combined**. Bring the knowledge from every declared predecessor.

#### From 012-platform-convergence-c3

[Predecessor guide](/docs/learning/state-012-platform-convergence-c3)

- **Carry forward:** Trading, Kubernetes and observability.
- **Why move:** A working application does not yet explain its security boundaries.
- **Add or revise:** Add staged controls, bounded experiments, independent outcome evidence and a method for comparing security cost.
- **Evidence to collect:** Positive trading plus attributable negative checks and residual-authority outcomes in the same pinned deployment; matched-workload cost measurements before crediting an alternative control.
- **Objectives:** `attribute-control`, `measure-residual`, `reproduce-recover`, `measure-control-cost`

| Before | After |
| --- | --- |
| C3 demonstrates normal trading. | Target: learners can reproduce layered security, explain residual risk and evaluate security/cost tradeoffs; integrated acceptance and performance measurements are pending. |

### Concepts before tools

- A reachable destination is not unlimited database authority; scoped service authority is not end-user business authorization.
- An alert or killed process does not prove that impact was prevented.
- A compensating control must meet the same security objective and preserve business correctness; fewer application code lines or faster requests alone do not establish an equivalent boundary.
- Security cost depends on the path: request latency, committed settlement and visible notifications are different outcomes, and moving work to a proxy or asynchronous queue does not remove its cost.

**Runtime prerequisites:** The integrated state is planned. Prototype onboarding is explicitly limited to its verified host and fixture scope; run only one full cluster at a time.

### Learning objectives

- **attribute-control:** Explain which security layer intervened using correlated decisions and independent state evidence.
- **measure-residual:** Distinguish denied out-of-grant operations from residual misuse of legitimate service authority, then compare detection with prevention.
- **reproduce-recover:** Reproduce a bounded experiment, restore synthetic data and verify that legitimate trading continues within a measured resource budget.
- **measure-control-cost:** Compare a control and a proposed replacement against the same security and business-correctness outcomes, using per-path p95/p99 latency, throughput, resource use and operating effort to justify retaining, replacing, combining or deferring them.

### Guided walkthrough

#### 1. control-boundaries (unavailable)

Objectives: `attribute-control`, `measure-residual`, `reproduce-recover`.

Planned integrated walkthrough: predict a decision, run positive and negative controls, inspect effects, compare runtime modes and reset. Prototype checkpoint evidence is available separately.

**Expected observation and meaning:** Attribute each decision and resulting state; do not infer prevention from an alert or claim a fixture is integrated.

Supporting material: [quickstart](/specs/traderx-security-lab/quickstart) · [tasks](/specs/traderx-security-lab/tasks) · [spec](/specs/traderx-security-lab/spec).

#### 2. security-cost-comparison (unavailable)

Objectives: `measure-control-cost`.

Planned exercise after cumulative baseline acceptance: choose one path, such as order submission through committed settlement, and predict the cost of its controls. Declare workload and trading-owner budgets, collect repeated baseline measurements, then evaluate a separately gated alternative against identical security and correctness checks. Keep operator lookup, reads and asynchronous notification timings distinct. A service-mesh comparison belongs to the separate follow-on, not this baseline implementation.

**Expected observation and meaning:** An evidence-backed decision joins the intervening layer and final SQL/message effects with p95/p99 latency, throughput, errors/queues, CPU/memory and whole-system operating effort. Report sample counts and uncertainty. Record unmeasured or incomplete results explicitly; a mesh reducing code or overhead remains a hypothesis until tested.

Supporting material: [security-cost-evaluation](/specs/traderx-security-lab/system/security-cost-evaluation) · [platform-control-comparison](/specs/traderx-security-lab/system/platform-control-comparison).

### Demonstrate your understanding

**Question (`attribute-control`, `measure-residual`, `reproduce-recover`):** A service talks to its allowed database and a runtime alert fires. What proves prevention and successful recovery?

**Assessment guidance:** Inspect independent canary and downstream effects after settling, compare the same inputs across profiles, reset and rerun positive trading; record resource costs and limitations.

**Question (`measure-control-cost`):** A proposed service mesh removes application TLS configuration and improves average response time. What evidence would justify it as a replacement or compensating control, and what responsibility might still belong to the application?

**Assessment guidance:** Compare the same pinned workload, identities, threats, failure cases and independent business outcomes, including cancellation, replay and within-grant misuse. Keep account authorization unless the candidate actually receives and enforces that context. Compare per-path p95/p99 and settlement latency, throughput, errors/queues, CPU/memory and proxy/control-plane resource use, plus setup, rotation, debugging and upgrade effort. Record sample counts, uncertainty, residual risk and an accountable retain/replace/combine/defer decision against declared budgets. Current measurements are absent and budgets are unspecified; no efficiency or equivalent-protection claim is yet justified.

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

**Objectives:** `measure-control-cost`.

**Check the starting point:** Where does a request wait before its business effect is committed, and which component has enough identity context to authorize that effect?

**Ask before the experiment:** Predict which cost a gateway or service mesh might remove, move or add, and which account-level decision it cannot make from workload identity alone.

**Hints, in order:**

1. Draw one complete request-to-effect path before selecting timing points; include queues and asynchronous work.
2. Replay the same load and negative scenarios, count unsuccessful work, and compare tail latency with independent final state.
3. Count proxy and control-plane resources and operating effort alongside application code removed; keep an unmeasured result unknown.

**Misconception to probe (not a fact):** A service mesh with less application code and a lower average latency necessarily provides equivalent security at lower total cost.

**Evidence to ask the learner for:** Pinned baseline/candidate configurations, identical security and business-correctness results, matched-load per-path p95/p99 with sample counts and uncertainty, whole-system resource and operating costs, declared budgets and a decision documenting residual risk.

### Scope and limitations

- Planned generated state; current evidence covers individual checkpoints and candidate integrations only.
- CVE/OSERA is optional and planned; CALM is a separate successor. Local checks are not compliance certification.
- Per-path performance and operating costs are unmeasured, and trading-owner latency/availability budgets are not yet declared. Service-mesh or ingress savings are hypotheses for a separate follow-on comparison; neither that comparison nor CALM is required to finish the manually established baseline.


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

