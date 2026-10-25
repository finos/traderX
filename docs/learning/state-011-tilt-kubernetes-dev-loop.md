---
title: "State 011: Tilt Local Dev on Kubernetes"
pagination_prev: null
pagination_next: null
---

# State 011 Learning Guide

<!-- Generated from specs/011-tilt-kubernetes-dev-loop/learning-contract.json; edit the source. -->

## Shorten the edit-and-observe loop

A slow rebuild-and-deploy loop interrupts experimentation. For developers already comfortable running TraderX on Kubernetes, use Tilt to connect a local change to a running workload and distinguish the last successful deployment from the latest attempted edit.

[How to learn with TraderX states](/docs/learning/how-to-learn) · [Structured lesson JSON](/learning/contracts/011-tilt-kubernetes-dev-loop.json)

**Maturity:** implemented. Run the exercises in a disposable local environment; use the quickstart for setup and cleanup.

### Starting point

The Kubernetes state requires explicit build and deployment steps for changes.

Entry route: **combined**. Bring the knowledge from every declared predecessor.

#### From 010-kubernetes-runtime

[Predecessor guide](/docs/learning/state-010-kubernetes-runtime)

- **Carry forward:** Run C2 on Kubernetes and explain ingress, service routing and pod readiness.
- **Why move:** The Kubernetes state requires explicit build and deployment steps for changes.
- **Add or revise:** Use Tilt to orchestrate the local Kubernetes development loop.
- **Evidence to collect:** The loop connects a local edit with a rebuilt or updated workload. Record which resource changed and how long it took; do not assume every edit uses live update. A failed rebuild can leave the old application serving. A responsive browser is therefore insufficient evidence that the latest edit deployed.
- **Objectives:** `trace-increment`, `interpret-evidence`

| Before | After |
| --- | --- |
| The Kubernetes state requires explicit build and deployment steps for changes. | Use Tilt to orchestrate the local Kubernetes development loop. |

### Concepts before tools

- A reconciliation loop tries to make running resources match desired configuration. File watching can trigger updates, but an update finishing does not prove the changed behavior.

**Runtime prerequisites:** Use the state quickstart for tool versions, generation, start and stop commands. Run one local state at a time because ports and generated output directories are shared.

### Learning objectives

- **trace-increment:** Correlate a local edit, its Tilt resource update and the visible application version.
- **interpret-evidence:** Explain the evidence boundary: A failed rebuild can leave the old application serving. A responsive browser is therefore insufficient evidence that the latest edit deployed.

### Guided walkthrough

#### 1. observe (available)

Objectives: `trace-increment`.

Follow the state quickstart and inspect the generated Tiltfile and watched paths. In a disposable generated checkout make a visible UI text change, observe the Tilt resource update, and reload the UI to verify that the change reached the browser.

**Expected observation and meaning:** The loop connects a local edit with a rebuilt or updated workload. Record which resource changed and how long it took; do not assume every edit uses live update.

Supporting material: [quickstart](/specs/tilt-kubernetes-dev-loop/quickstart) · [architecture](/specs/tilt-kubernetes-dev-loop/system/architecture) · [runtime-topology](/specs/tilt-kubernetes-dev-loop/system/runtime-topology).

#### 2. challenge (available)

Objectives: `interpret-evidence`.

Introduce a reversible syntax error in that disposable file, observe the build error, then undo it. Check whether the browser still shows the previous successful version while the new build fails.

**Expected observation and meaning:** A failed rebuild can leave the old application serving. A responsive browser is therefore insufficient evidence that the latest edit deployed.

Supporting material: [spec](/specs/tilt-kubernetes-dev-loop/spec) · [contract-delta](/specs/tilt-kubernetes-dev-loop/contracts/contract-delta).

### Demonstrate your understanding

**Question (`trace-increment`, `interpret-evidence`):** How can you prove the browser is serving your latest edit?

**Assessment guidance:** Correlate the successful Tilt update with the exact visible change. Explain why a failed build and a healthy old pod can coexist.

### Work with a learning partner

Use the [learning-partner protocol](/docs/learning/how-to-learn#learn-with-an-agent) with a human or an agent. Ask for a prediction before running the exercise, offer one hint at a time, and discuss the assessment guidance after the learner has attempted an explanation.

**Objectives:** `trace-increment`, `interpret-evidence`.

**Check the starting point:** What steps connected a source edit to a new deployed version in the Kubernetes state?

**Ask before the experiment:** Predict which version the browser may show while a new build fails.

**Hints, in order:**

1. Identify the watched file and the Tilt resource affected by the edit.
2. Correlate the successful resource update with the exact visible change rather than with browser responsiveness.

**Misconception to probe (not a fact):** A responsive browser proves that the latest local edit has deployed.

**Evidence to ask the learner for:** Ask for the attempted edit, Tilt update/build result and observed UI version; distinguish the latest attempt from the last successful deployment.

### Scope and limitations

- A failed rebuild can leave the old application serving. A responsive browser is therefore insufficient evidence that the latest edit deployed.
- This is an educational local demonstration. Passing its checks does not establish production readiness, financial settlement, or correctness under every failure mode.


## Position In Learning Graph

- Previous state(s): [010-kubernetes-runtime](/docs/learning/state-010-kubernetes-runtime)
- Dotted-line parent(s): none
- Next state(s): [012-platform-convergence-c3](/docs/learning/state-012-platform-convergence-c3)

## Convergence Metadata

- Convergence state: `no`
- Convergence level: `none`
- Lineage role: `canonical`
- Nearest previous convergence: `none`
- Nearest next convergence: `none`

## Rendered Code

- Generated branch: [code/generated-state-011-tilt-kubernetes-dev-loop](https://github.com/finos/traderX/tree/code/generated-state-011-tilt-kubernetes-dev-loop)
- Authoring branch (spec source): [main](https://github.com/finos/traderX/tree/main)

## Code Comparison With Previous State

- Compare against `010-kubernetes-runtime`: [code/generated-state-010-kubernetes-runtime...code/generated-state-011-tilt-kubernetes-dev-loop](https://github.com/finos/traderX/compare/code%2Fgenerated-state-010-kubernetes-runtime...code%2Fgenerated-state-011-tilt-kubernetes-dev-loop)

## Plain-English Code Delta

- **Flow Impact:** No functional flow deltas. Baseline flows `F1`-`F6` and startup behavior remain compatible with state `010`, including inherited price snapshot+stream freshness behavior and push-based realtime blotter subscriptions.

## Run This State

```bash
./scripts/start-state-011-tilt-kubernetes-dev-loop-generated.sh
```

## Canonical Spec Links

- State spec pack: [/specs/tilt-kubernetes-dev-loop](/specs/tilt-kubernetes-dev-loop)
- Architecture: [/specs/tilt-kubernetes-dev-loop/system/architecture](/specs/tilt-kubernetes-dev-loop/system/architecture)
- Flows / topology: [/specs/tilt-kubernetes-dev-loop/system/runtime-topology](/specs/tilt-kubernetes-dev-loop/system/runtime-topology)
- Research: [link](/specs/tilt-kubernetes-dev-loop/research)
- Data model: [link](/specs/tilt-kubernetes-dev-loop/data-model)
- Quickstart: [link](/specs/tilt-kubernetes-dev-loop/quickstart)

