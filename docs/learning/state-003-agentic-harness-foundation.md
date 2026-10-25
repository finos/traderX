---
title: "State 003: Agentic Harness Foundation"
pagination_prev: null
pagination_next: null
---

# State 003 Learning Guide

<!-- Generated from specs/003-agentic-harness-foundation/learning-contract.json; edit the source. -->

## Make an agent work within an explicit contract

A working application is difficult to change safely when its conventions live only in a contributor’s memory. This chapter is for developers introducing agent-assisted changes: make the source of authority and the verification process explicit, then test whether an edit survives generation.

[How to learn with TraderX states](/docs/learning/how-to-learn) · [Structured lesson JSON](/learning/contracts/003-agentic-harness-foundation.json)

**Maturity:** implemented. Run the exercises in a disposable local environment; use the quickstart for setup and cleanup.

### Starting point

The edge-proxied application works, but a contributor must reconstruct conventions from code.

Entry route: **combined**. Bring the knowledge from every declared predecessor.

#### From 002-edge-proxy-uncontainerized

[Predecessor guide](/docs/learning/state-002-edge-proxy-uncontainerized)

- **Carry forward:** Route UI, REST and streaming traffic through one NGINX edge while retaining the baseline business flow.
- **Why move:** The edge-proxied application works, but a contributor must reconstruct conventions from code.
- **Add or revise:** Add generated instructions, architecture context and contributor guidance for repeatable agent-assisted work.
- **Evidence to collect:** The harness connects a proposed change to its authority and verification. Its value is a reproducible workflow, not a claim that the agent is correct. The disposable output change is lost or replaced. Persistent customization belongs in canonical sources or overlays.
- **Objectives:** `trace-increment`, `interpret-evidence`

| Before | After |
| --- | --- |
| The edge-proxied application works, but a contributor must reconstruct conventions from code. | Add generated instructions, architecture context and contributor guidance for repeatable agent-assisted work. |

### Concepts before tools

- An agent harness is the instructions and verification environment around an agent. Generated files are outputs; changing an output alone does not change the next generation.

**Runtime prerequisites:** Use the state quickstart for tool versions, generation, start and stop commands. Run one local state at a time because ports and generated output directories are shared.

### Learning objectives

- **trace-increment:** Locate the canonical source and verification command for a proposed change, and explain why an output-only edit is not durable.
- **interpret-evidence:** Explain the evidence boundary: The disposable output change is lost or replaced. Persistent customization belongs in canonical sources or overlays.

### Guided walkthrough

#### 1. observe (available)

Objectives: `trace-increment`.

Generate this state and inspect generated/code/target-generated/AGENTS.md, ARCHITECTURE.md and CONTRIBUTING.md. Pick the trade request path and locate its source contract, implementation and documented verification command.

**Expected observation and meaning:** The harness connects a proposed change to its authority and verification. Its value is a reproducible workflow, not a claim that the agent is correct.

Supporting material: [quickstart](/specs/agentic-harness-foundation/quickstart) · [architecture](/specs/agentic-harness-foundation/system/architecture) · [runtime-topology](/specs/agentic-harness-foundation/system/runtime-topology).

#### 2. challenge (available)

Objectives: `interpret-evidence`.

In a disposable generated checkout, add a comment to an output file, regenerate from unchanged sources, and compare the result. Keep this experiment separate from authored changes.

**Expected observation and meaning:** The disposable output change is lost or replaced. Persistent customization belongs in canonical sources or overlays.

Supporting material: [spec](/specs/agentic-harness-foundation/spec) · [contract-delta](/specs/agentic-harness-foundation/contracts/contract-delta).

### Demonstrate your understanding

**Question (`trace-increment`, `interpret-evidence`):** Where would you make a durable behavior change, and what evidence would you request from an agent?

**Assessment guidance:** Identify the canonical spec/template or overlay and a relevant behavior check. Generated instructions cannot substitute for the check result.

### Work with a learning partner

Use the [learning-partner protocol](/docs/learning/how-to-learn#learn-with-an-agent) with a human or an agent. Ask for a prediction before running the exercise, offer one hint at a time, and discuss the assessment guidance after the learner has attempted an explanation.

**Objectives:** `trace-increment`, `interpret-evidence`.

**Check the starting point:** Where do durable changes belong when a checkout is generated from canonical sources?

**Ask before the experiment:** Predict what regeneration will do to the comment added only to disposable generated output.

**Hints, in order:**

1. Locate the instruction that names the authoritative source of the chosen component.
2. Compare that source with the regenerated output and identify which verification command tests behavior.

**Misconception to probe (not a fact):** Generated instructions guarantee correctness, or an output-only edit becomes a lasting customization.

**Evidence to ask the learner for:** Ask for the source path, before/after generated diff and relevant verification result; distinguish reading an instruction from executing its check.

### Scope and limitations

- The disposable output change is lost or replaced. Persistent customization belongs in canonical sources or overlays.
- This is an educational local demonstration. Passing its checks does not establish production readiness, financial settlement, or correctness under every failure mode.


## Position In Learning Graph

- Previous state(s): [002-edge-proxy-uncontainerized](/docs/learning/state-002-edge-proxy-uncontainerized)
- Dotted-line parent(s): none
- Next state(s): [004-containerized-compose-runtime](/docs/learning/state-004-containerized-compose-runtime)

## Convergence Metadata

- Convergence state: `no`
- Convergence level: `none`
- Lineage role: `prelude`
- Nearest previous convergence: `none`
- Nearest next convergence: `none`

## Rendered Code

- Generated branch: [code/generated-state-003-agentic-harness-foundation](https://github.com/finos/traderX/tree/code/generated-state-003-agentic-harness-foundation)
- Authoring branch (spec source): [main](https://github.com/finos/traderX/tree/main)

## Code Comparison With Previous State

- Compare against `002-edge-proxy-uncontainerized`: [code/generated-state-002-edge-proxy-uncontainerized...code/generated-state-003-agentic-harness-foundation](https://github.com/finos/traderX/compare/code%2Fgenerated-state-002-edge-proxy-uncontainerized...code%2Fgenerated-state-003-agentic-harness-foundation)

## Plain-English Code Delta

- **Added:** Generated codebase root includes `AGENTS.md` with agent operating contract.
- **Added:** Generated codebase root includes `ARCHITECTURE.md` summarizing module boundaries and extension points.
- **Added:** Generated codebase root includes `CONTRIBUTING.md` clarifying generated snapshot contribution policy.
- **Changed:** State lineage introduces a new prelude state before containerized compose baseline.
- **Flow Impact:** No runtime endpoint or service-flow changes compared with state `002`.
- **Flow Impact:** Development workflow gains explicit agent guidance and contribution boundary in generated outputs.

## Run This State

```bash
./scripts/start-state-003-agentic-harness-foundation-generated.sh
```

## Canonical Spec Links

- State spec pack: [/specs/agentic-harness-foundation](/specs/agentic-harness-foundation)
- Architecture: [/specs/agentic-harness-foundation/system/architecture](/specs/agentic-harness-foundation/system/architecture)
- Flows / topology: [/specs/agentic-harness-foundation/system/runtime-topology](/specs/agentic-harness-foundation/system/runtime-topology)
- Research: [link](/specs/agentic-harness-foundation/research)
- Data model: [link](/specs/agentic-harness-foundation/data-model)
- Quickstart: [link](/specs/agentic-harness-foundation/quickstart)

