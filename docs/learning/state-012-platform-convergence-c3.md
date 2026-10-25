---
title: "State 012: Platform Convergence C3"
pagination_prev: null
pagination_next: null
---

# State 012 Learning Guide

<!-- Generated from specs/012-platform-convergence-c3/learning-contract.json; edit the source. -->

## Establish a reusable platform checkpoint

Before branching into more integrations, establish what the platform actually contains. This chapter is for developers extending C3: gather functional and platform evidence together so that a reusable checkpoint means more than a collection of healthy containers.

[How to learn with TraderX states](/docs/learning/how-to-learn)

**Maturity:** implemented. Run the exercises in a disposable local environment; use the quickstart for setup and cleanup.

### Starting point

Tilt supplies the local Kubernetes loop and carries the earlier C2 trading capabilities.

Entry route: **combined**. Bring the knowledge from every declared predecessor.

#### From 011-tilt-kubernetes-dev-loop

[Predecessor guide](/docs/learning/state-011-tilt-kubernetes-dev-loop)

- **Carry forward:** Use Tilt to orchestrate the local Kubernetes development loop.
- **Why move:** Tilt supplies the local Kubernetes loop and carries the earlier C2 trading capabilities.
- **Add or revise:** Treat C3 as a combined platform and functional checkpoint for subsequent branches.
- **Evidence to collect:** C3 combines the C2 order/pricing/observability knowledge carried through states 010 and 011 with the development platform. One successful layer is not sufficient to establish the checkpoint. Published images can differ from local edits and may use emulation on Apple Silicon. Startup timing alone is not a functional regression verdict.
- **Objectives:** `trace-increment`, `interpret-evidence`

| Before | After |
| --- | --- |
| Tilt supplies the local Kubernetes loop and carries the earlier C2 trading capabilities. | Treat C3 as a combined platform and functional checkpoint for subsequent branches. |

### Concepts before tools

- Convergence records a compatible combination of capabilities. A dotted relationship records retained context; it is not automatically a second generation parent.
- State 011 is the required incoming route. The dotted state 009 relationship highlights retained C2 knowledge already carried through states 010 and 011; it is not an alternative entry route that bypasses Kubernetes and Tilt.

**Runtime prerequisites:** Use the state quickstart for tool versions, generation, start and stop commands. Run one local state at a time because ports and generated output directories are shared.

### Learning objectives

- **trace-increment:** Demonstrate the retained C2 order behavior and C3 platform assets for the same generated snapshot.
- **interpret-evidence:** Explain the evidence boundary: Published images can differ from local edits and may use emulation on Apple Silicon. Startup timing alone is not a functional regression verdict.

### Guided walkthrough

#### 1. observe (available)

Objectives: `trace-increment`.

Start C3 using the kind quickstart and run its smoke test. Exercise a small order and inspect its telemetry, then inspect the generated Kubernetes and Tilt assets. Record both business and platform evidence for the same snapshot.

**Expected observation and meaning:** C3 combines the C2 order/pricing/observability knowledge carried through states 010 and 011 with the development platform. One successful layer is not sufficient to establish the checkpoint.

Supporting material: [quickstart](/specs/platform-convergence-c3/quickstart) · [architecture](/specs/platform-convergence-c3/system/architecture) · [runtime-topology](/specs/platform-convergence-c3/system/runtime-topology).

#### 2. challenge (available)

Objectives: `interpret-evidence`.

Compare the published-image and local-build procedures in the quickstart. Record the selected image source and target platform before interpreting a slow startup or an unexpected UI version.

**Expected observation and meaning:** Published images can differ from local edits and may use emulation on Apple Silicon. Startup timing alone is not a functional regression verdict.

Supporting material: [spec](/specs/platform-convergence-c3/spec) · [contract-delta](/specs/platform-convergence-c3/contracts/contract-delta).

### Demonstrate your understanding

**Question (`trace-increment`, `interpret-evidence`):** Why is state 009 shown as a dotted parent when state 011 is the declared predecessor?

**Assessment guidance:** C2 supplies retained functional knowledge through 010 and 011; 011 is the actual generation lineage. Demonstrate both functional and platform behavior, without inventing a separate merge.

### Scope and limitations

- Published images can differ from local edits and may use emulation on Apple Silicon. Startup timing alone is not a functional regression verdict.
- This is an educational local demonstration. Passing its checks does not establish production readiness, financial settlement, or correctness under every failure mode.


## Position In Learning Graph

- Previous state(s): [011-tilt-kubernetes-dev-loop](/docs/learning/state-011-tilt-kubernetes-dev-loop)
- Dotted-line parent(s): [009-order-management-matcher](/docs/learning/state-009-order-management-matcher)
- Next state(s): [013-radius-kubernetes-platform](/docs/learning/state-013-radius-kubernetes-platform), [014-fdc3-intent-interoperability](/docs/learning/state-014-fdc3-intent-interoperability)

## Convergence Metadata

- Convergence state: `yes`
- Convergence level: `C3`
- Lineage role: `canonical`
- Nearest previous convergence: [009-order-management-matcher](/docs/learning/state-009-order-management-matcher)
- Nearest next convergence: `none`

## Rendered Code

- Generated branch: [code/generated-state-012-platform-convergence-c3](https://github.com/finos/traderX/tree/code/generated-state-012-platform-convergence-c3)
- Authoring branch (spec source): [main](https://github.com/finos/traderX/tree/main)

## Code Comparison With Previous State

- Compare against `011-tilt-kubernetes-dev-loop`: [code/generated-state-011-tilt-kubernetes-dev-loop...code/generated-state-012-platform-convergence-c3](https://github.com/finos/traderX/compare/code%2Fgenerated-state-011-tilt-kubernetes-dev-loop...code%2Fgenerated-state-012-platform-convergence-c3)

## Plain-English Code Delta

- **Flow Impact:** No functional flow deltas. Baseline flows `F1`-`F6` and startup behavior remain compatible with state `011`, including inherited price snapshot+stream freshness behavior and push-based realtime blotter subscriptions.

## Run This State

```bash
./scripts/start-state-012-platform-convergence-c3-generated.sh
```

## Canonical Spec Links

- State spec pack: [/specs/platform-convergence-c3](/specs/platform-convergence-c3)
- Architecture: [/specs/platform-convergence-c3/system/architecture](/specs/platform-convergence-c3/system/architecture)
- Flows / topology: [/specs/platform-convergence-c3/system/runtime-topology](/specs/platform-convergence-c3/system/runtime-topology)
- Research: [link](/specs/platform-convergence-c3/research)
- Data model: [link](/specs/platform-convergence-c3/data-model)
- Quickstart: [link](/specs/platform-convergence-c3/quickstart)
- State ADR: [link](/docs/adr/008-convergence-state-model)
