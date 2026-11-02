---
title: "State 013: Radius Platform on Kubernetes (Optional)"
pagination_prev: null
pagination_next: null
---

# State 013 Learning Guide

<!-- Generated from specs/013-radius-kubernetes-platform/learning-contract.json; edit the source. -->

## Explore a platform abstraction as an alternative

Platform teams may want application intent expressed above individual Kubernetes resources. This optional chapter is for developers evaluating that trade-off: trace a Radius declaration into deployed resources and identify which operational responsibilities the abstraction moves.

[How to learn with TraderX states](/docs/learning/how-to-learn) · [Structured lesson JSON](/learning/contracts/013-radius-kubernetes-platform.json)

**Maturity:** implemented. Run the exercises in a disposable local environment; use the quickstart for setup and cleanup.

### Starting point

C3 exposes Kubernetes resources and their development lifecycle directly.

Entry route: **combined**. Bring the knowledge from every declared predecessor.

#### From 012-platform-convergence-c3

[Predecessor guide](/docs/learning/state-012-platform-convergence-c3)

- **Carry forward:** Treat C3 as a combined platform and functional checkpoint for subsequent branches.
- **Why move:** C3 exposes Kubernetes resources and their development lifecycle directly.
- **Add or revise:** Use Radius to describe the application and its resource relationships on Kubernetes.
- **Evidence to collect:** The application model adds a layer above Kubernetes. The underlying trading contract remains a useful regression check. A valid application description is not proof that required infrastructure was provisioned. The platform and application have distinct failure evidence.
- **Objectives:** `trace-increment`, `interpret-evidence`

| Before | After |
| --- | --- |
| C3 exposes Kubernetes resources and their development lifecycle directly. | Use Radius to describe the application and its resource relationships on Kubernetes. |

### Concepts before tools

- A platform abstraction declares application intent and resolves infrastructure through its deployment model. It shifts responsibility rather than removing infrastructure.

**Runtime prerequisites:** Use the state quickstart for tool versions, generation, start and stop commands. Run one local state at a time because ports and generated output directories are shared.

### Learning objectives

- **trace-increment:** Trace a Radius application dependency to its deployed Kubernetes resources and explain the additional abstraction.
- **interpret-evidence:** Explain the evidence boundary: A valid application description is not proof that required infrastructure was provisioned. The platform and application have distinct failure evidence.

### Guided walkthrough

#### 1. observe (available)

Objectives: `trace-increment`.

Follow the Radius state quickstart and smoke test. Compare the generated Radius application definition with the resulting Kubernetes resources. Trace one service dependency from the application model to the deployed workload.

**Expected observation and meaning:** The application model adds a layer above Kubernetes. The underlying trading contract remains a useful regression check.

Supporting material: [quickstart](/specs/radius-kubernetes-platform/quickstart) · [architecture](/specs/radius-kubernetes-platform/system/architecture) · [runtime-topology](/specs/radius-kubernetes-platform/system/runtime-topology).

#### 2. challenge (available)

Objectives: `interpret-evidence`.

Inspect the model and deployment output for an unresolved resource or deployment prerequisite. Explain how you would distinguish a Radius provisioning error from an application health failure using those outputs.

**Expected observation and meaning:** A valid application description is not proof that required infrastructure was provisioned. The platform and application have distinct failure evidence.

Supporting material: [spec](/specs/radius-kubernetes-platform/spec) · [contract-delta](/specs/radius-kubernetes-platform/contracts/contract-delta).

### Demonstrate your understanding

**Question (`trace-increment`, `interpret-evidence`):** When would you choose this branch over continuing directly from C3?

**Assessment guidance:** Justify whether the resource abstraction helps your platform use case and name its operational cost. State 013 is optional and is not required for state 014.

### Work with a learning partner

Use the [learning-partner protocol](/docs/learning/how-to-learn#learn-with-an-agent) with a human or an agent. Ask for a prediction before running the exercise, offer one hint at a time, and discuss the assessment guidance after the learner has attempted an explanation.

**Objectives:** `trace-increment`, `interpret-evidence`.

**Check the starting point:** Which Kubernetes responsibilities does the C3 application expose directly?

**Ask before the experiment:** Predict what a valid Radius declaration establishes before provisioning finishes.

**Hints, in order:**

1. Trace one declared resource relationship to a resulting Kubernetes resource.
2. Separate platform provisioning output from application readiness and the business smoke result.

**Misconception to probe (not a fact):** A platform abstraction removes infrastructure responsibility or makes the application healthy by definition.

**Evidence to ask the learner for:** Ask for the declaration-to-resource mapping, deployment/health observations and a reasoned comparison with staying on C3.

### Scope and limitations

- A valid application description is not proof that required infrastructure was provisioned. The platform and application have distinct failure evidence.
- This is an educational local demonstration. Passing its checks does not establish production readiness, financial settlement, or correctness under every failure mode.


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

- Generated branch: [code/generated-state-013-radius-kubernetes-platform](https://github.com/finos/traderX/tree/code/generated-state-013-radius-kubernetes-platform)
- Authoring branch (spec source): [main](https://github.com/finos/traderX/tree/main)

## Code Comparison With Previous State

- Compare against `012-platform-convergence-c3`: [code/generated-state-012-platform-convergence-c3...code/generated-state-013-radius-kubernetes-platform](https://github.com/finos/traderX/compare/code%2Fgenerated-state-012-platform-convergence-c3...code%2Fgenerated-state-013-radius-kubernetes-platform)

## Plain-English Code Delta

- **Flow Impact:** No functional flow deltas. Baseline flows `F1`-`F6` and startup behavior remain compatible with state `012`.

## Run This State

```bash
./scripts/start-state-013-radius-kubernetes-platform-generated.sh
```

## Canonical Spec Links

- State spec pack: [/specs/radius-kubernetes-platform](/specs/radius-kubernetes-platform)
- Architecture: [/specs/radius-kubernetes-platform/system/architecture](/specs/radius-kubernetes-platform/system/architecture)
- Flows / topology: [/specs/radius-kubernetes-platform/system/runtime-topology](/specs/radius-kubernetes-platform/system/runtime-topology)
- Research: [link](/specs/radius-kubernetes-platform/research)
- Data model: [link](/specs/radius-kubernetes-platform/data-model)
- Quickstart: [link](/specs/radius-kubernetes-platform/quickstart)

