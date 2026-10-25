---
title: "State 007: Observability with LGTM on Compose"
pagination_prev: null
pagination_next: null
---

# State 007 Learning Guide

<!-- Generated from specs/007-observability-lgtm-compose/learning-contract.json; edit the source. -->

## Explain behavior with telemetry

When a trade seems to disappear, a healthy service status gives little help. This chapter is for developers diagnosing a distributed workflow: use complementary telemetry signals to narrow a question, and learn why missing telemetry cannot settle it.

[How to learn with TraderX states](/docs/learning/how-to-learn) · [Structured lesson JSON](/learning/contracts/007-observability-lgtm-compose.json)

**Maturity:** implemented. Run the exercises in a disposable local environment; use the quickstart for setup and cleanup.

### Starting point

NATS and PostgreSQL carry the workflow, but scattered logs make diagnosis difficult.

Entry route: **combined**. Bring the knowledge from every declared predecessor.

#### From 006-messaging-nats-replacement

[Predecessor guide](/docs/learning/state-006-messaging-nats-replacement)

- **Carry forward:** Replace internal messaging with NATS while preserving the trade-to-position workflow.
- **Why move:** NATS and PostgreSQL carry the workflow, but scattered logs make diagnosis difficult.
- **Add or revise:** Add LGTM telemetry to connect a user action with logs, metrics and traces.
- **Evidence to collect:** The signals provide complementary evidence. Record which services are represented and which gaps remain instead of treating an empty panel as a successful run. Missing telemetry can reflect selection, sampling or collection problems. It is not evidence that no trade exists.
- **Objectives:** `trace-increment`, `interpret-evidence`

| Before | After |
| --- | --- |
| NATS and PostgreSQL carry the workflow, but scattered logs make diagnosis difficult. | Add LGTM telemetry to connect a user action with logs, metrics and traces. |

### Concepts before tools

- A metric summarizes measurements; a log records an event; a trace relates timed operations. Correlation is evidence of a path, not proof that every business effect committed.

**Runtime prerequisites:** Use the state quickstart for tool versions, generation, start and stop commands. Run one local state at a time because ports and generated output directories are shared.

### Learning objectives

- **trace-increment:** Correlate one trade with available logs, metrics and traces, and identify gaps in the observed request path.
- **interpret-evidence:** Explain the evidence boundary: Missing telemetry can reflect selection, sampling or collection problems. It is not evidence that no trade exists.

### Guided walkthrough

#### 1. observe (available)

Objectives: `trace-increment`.

Start this state and open Grafana through /grafana/ as described in the quickstart. Submit one small trade and note its time and identifier. Find the relevant service logs and metrics, and inspect any available trace for that request.

**Expected observation and meaning:** The signals provide complementary evidence. Record which services are represented and which gaps remain instead of treating an empty panel as a successful run.

Supporting material: [quickstart](/specs/observability-lgtm-compose/quickstart) · [architecture](/specs/observability-lgtm-compose/system/architecture) · [runtime-topology](/specs/observability-lgtm-compose/system/runtime-topology).

#### 2. challenge (available)

Objectives: `interpret-evidence`.

Change the dashboard time range to exclude the request and compare it with a range that includes it. If a trace is absent, inspect instrumentation and collection health before concluding the request did not run.

**Expected observation and meaning:** Missing telemetry can reflect selection, sampling or collection problems. It is not evidence that no trade exists.

Supporting material: [spec](/specs/observability-lgtm-compose/spec) · [contract-delta](/specs/observability-lgtm-compose/contracts/contract-delta).

### Demonstrate your understanding

**Question (`trace-increment`, `interpret-evidence`):** Can you diagnose a missing trade from an empty dashboard alone?

**Assessment guidance:** No. Check time range and collection, then reconcile the persisted trade and processing evidence. Name the limits of the available signals.

### Work with a learning partner

Use the [learning-partner protocol](/docs/learning/how-to-learn#learn-with-an-agent) with a human or an agent. Ask for a prediction before running the exercise, offer one hint at a time, and discuss the assessment guidance after the learner has attempted an explanation.

**Objectives:** `trace-increment`, `interpret-evidence`.

**Check the starting point:** What question can a log answer that a service-health indicator cannot?

**Ask before the experiment:** Predict what an empty dashboard means when the time range excludes your request.

**Hints, in order:**

1. Check the selected time window and whether the collector received any signals.
2. Compare the available logs, metrics and trace with the separately recorded trade identifier.

**Misconception to probe (not a fact):** Missing telemetry proves that the business action never occurred.

**Evidence to ask the learner for:** Ask for the request time, selected range, available correlated signals and missing spans; distinguish telemetry gaps from absent business records.

### Scope and limitations

- Missing telemetry can reflect selection, sampling or collection problems. It is not evidence that no trade exists.
- This is an educational local demonstration. Passing its checks does not establish production readiness, financial settlement, or correctness under every failure mode.


## Position In Learning Graph

- Previous state(s): [006-messaging-nats-replacement](/docs/learning/state-006-messaging-nats-replacement)
- Dotted-line parent(s): none
- Next state(s): [008-pricing-awareness-market-data](/docs/learning/state-008-pricing-awareness-market-data)

## Convergence Metadata

- Convergence state: `yes`
- Convergence level: `C1`
- Lineage role: `canonical`
- Nearest previous convergence: [004-containerized-compose-runtime](/docs/learning/state-004-containerized-compose-runtime)
- Nearest next convergence: [009-order-management-matcher](/docs/learning/state-009-order-management-matcher)

## Rendered Code

- Generated branch: [code/generated-state-007-observability-lgtm-compose](https://github.com/finos/traderX/tree/code/generated-state-007-observability-lgtm-compose)
- Authoring branch (spec source): [main](https://github.com/finos/traderX/tree/main)

## Code Comparison With Previous State

- Compare against `006-messaging-nats-replacement`: [code/generated-state-006-messaging-nats-replacement...code/generated-state-007-observability-lgtm-compose](https://github.com/finos/traderX/compare/code%2Fgenerated-state-006-messaging-nats-replacement...code%2Fgenerated-state-007-observability-lgtm-compose)

## Plain-English Code Delta

- **Flow Impact:** No functional flow changes from state `006`.
- **Flow Impact:** Existing flow IDs remain valid; this state only adds runtime observability capabilities.

## Run This State

```bash
./scripts/start-state-007-observability-lgtm-compose-generated.sh
```

## Canonical Spec Links

- State spec pack: [/specs/observability-lgtm-compose](/specs/observability-lgtm-compose)
- Architecture: [/specs/observability-lgtm-compose/system/architecture](/specs/observability-lgtm-compose/system/architecture)
- Flows / topology: [/specs/observability-lgtm-compose/system/runtime-topology](/specs/observability-lgtm-compose/system/runtime-topology)
- Research: [link](/specs/observability-lgtm-compose/research)
- Data model: [link](/specs/observability-lgtm-compose/data-model)
- Quickstart: [link](/specs/observability-lgtm-compose/quickstart)
- State ADR: [link](/docs/adr/007-state-007-adopt-lgtm-observability-stack)
