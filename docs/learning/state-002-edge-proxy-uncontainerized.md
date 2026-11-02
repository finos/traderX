---
title: "State 002: Edge Proxy Uncontainerized"
pagination_prev: null
pagination_next: null
---

# State 002 Learning Guide

<!-- Generated from specs/002-edge-proxy-uncontainerized/learning-contract.json; edit the source. -->

## Give the browser one entry point

A browser should not need to know where every backend lives. For developers who have traced the baseline workflow, this chapter uses a reverse proxy to establish one public entry point and investigates why REST traffic and streaming traffic need separate attention.

[How to learn with TraderX states](/docs/learning/how-to-learn) · [Structured lesson JSON](/learning/contracts/002-edge-proxy-uncontainerized.json)

**Maturity:** implemented. Run the exercises in a disposable local environment; use the quickstart for setup and cleanup.

### Starting point

The baseline exposes services on separate local ports.

Entry route: **combined**. Bring the knowledge from every declared predecessor.

#### From 001-baseline-uncontainerized-parity

[Predecessor guide](/docs/learning/state-001-baseline-uncontainerized-parity)

- **Carry forward:** Trace the browser, trade service, event transport, processor, database and position view as one business workflow.
- **Why move:** The baseline exposes services on separate local ports.
- **Add or revise:** Route UI, REST and streaming traffic through one NGINX edge while retaining the baseline business flow.
- **Evidence to collect:** The browser uses one public origin while NGINX forwards to several services. A working account request alone does not establish that streaming upgrades work. Routing and business processing fail at different boundaries. A live HTTP endpoint does not establish a healthy event path.
- **Objectives:** `trace-increment`, `interpret-evidence`

| Before | After |
| --- | --- |
| The baseline exposes services on separate local ports. | Route UI, REST and streaming traffic through one NGINX edge while retaining the baseline business flow. |

### Concepts before tools

- An origin is a scheme, host and port. A reverse proxy forwards requests; a WebSocket upgrade keeps a streaming connection open.

**Runtime prerequisites:** Use the state quickstart for tool versions, generation, start and stop commands. Run one local state at a time because ports and generated output directories are shared.

### Learning objectives

- **trace-increment:** Map an account request and a streaming connection from the browser’s public origin to their separate upstream services.
- **interpret-evidence:** Explain the evidence boundary: Routing and business processing fail at different boundaries. A live HTTP endpoint does not establish a healthy event path.

### Guided walkthrough

#### 1. observe (available)

Objectives: `trace-increment`.

Open the proxied UI at the address in the quickstart. In browser Network tools reload accounts, submit a trade and inspect the streaming connection. Compare the public request paths with the upstream services in the topology.

**Expected observation and meaning:** The browser uses one public origin while NGINX forwards to several services. A working account request alone does not establish that streaming upgrades work.

Supporting material: [quickstart](/specs/edge-proxy-uncontainerized/quickstart) · [architecture](/specs/edge-proxy-uncontainerized/system/architecture) · [runtime-topology](/specs/edge-proxy-uncontainerized/system/runtime-topology).

#### 2. challenge (available)

Objectives: `interpret-evidence`.

In Network tools compare a normal REST response with the streaming connection handshake. If the blotter does not update, check the upstream service and proxy routing separately before retrying the trade.

**Expected observation and meaning:** Routing and business processing fail at different boundaries. A live HTTP endpoint does not establish a healthy event path.

Supporting material: [spec](/specs/edge-proxy-uncontainerized/spec).

### Demonstrate your understanding

**Question (`trace-increment`, `interpret-evidence`):** Which connection would you inspect when accounts load but the trade blotter stops updating?

**Assessment guidance:** Identify the streaming route and upgrade behavior, and distinguish it from the account REST route. Explain which upstream logs would narrow the failure.

### Work with a learning partner

Use the [learning-partner protocol](/docs/learning/how-to-learn#learn-with-an-agent) with a human or an agent. Ask for a prediction before running the exercise, offer one hint at a time, and discuss the assessment guidance after the learner has attempted an explanation.

**Objectives:** `trace-increment`, `interpret-evidence`.

**Check the starting point:** How did the baseline browser find each backend, and what constitutes an origin?

**Ask before the experiment:** Predict whether a successful account request establishes that streaming updates will also work.

**Hints, in order:**

1. Compare the browser-visible host and path for the REST and streaming connections.
2. Inspect the WebSocket handshake and its upstream route separately from a normal REST response.

**Misconception to probe (not a fact):** One working route proves every connection through the proxy is healthy.

**Evidence to ask the learner for:** Ask for the two observed connection paths and handshake/result, and an explanation of the corresponding upstream services.

### Scope and limitations

- Routing and business processing fail at different boundaries. A live HTTP endpoint does not establish a healthy event path.
- This is an educational local demonstration. Passing its checks does not establish production readiness, financial settlement, or correctness under every failure mode.


## Position In Learning Graph

- Previous state(s): [001-baseline-uncontainerized-parity](/docs/learning/state-001-baseline-uncontainerized-parity)
- Dotted-line parent(s): none
- Next state(s): [003-agentic-harness-foundation](/docs/learning/state-003-agentic-harness-foundation)

## Convergence Metadata

- Convergence state: `no`
- Convergence level: `none`
- Lineage role: `prelude`
- Nearest previous convergence: `none`
- Nearest next convergence: `none`

## Rendered Code

- Generated branch: [code/generated-state-002-edge-proxy-uncontainerized](https://github.com/finos/traderX/tree/code/generated-state-002-edge-proxy-uncontainerized)
- Authoring branch (spec source): [main](https://github.com/finos/traderX/tree/main)

## Code Comparison With Previous State

- Compare against `001-baseline-uncontainerized-parity`: [code/generated-state-001-baseline-uncontainerized-parity...code/generated-state-002-edge-proxy-uncontainerized](https://github.com/finos/traderX/compare/code%2Fgenerated-state-001-baseline-uncontainerized-parity...code%2Fgenerated-state-002-edge-proxy-uncontainerized)

## Plain-English Code Delta

- **Code focus:** Adds an edge proxy component and routes browser traffic through one origin.
- **Runtime behavior:** Keeps services uncontainerized while reducing client-side cross-origin complexity.
- **Learning takeaway:** Introduces ingress-style edge concerns before containerization.

## Run This State

```bash
./scripts/start-state-002-edge-proxy-generated.sh
```

## Canonical Spec Links

- State spec pack: [/specs/edge-proxy-uncontainerized](/specs/edge-proxy-uncontainerized)
- Architecture: [/specs/edge-proxy-uncontainerized/system/architecture](/specs/edge-proxy-uncontainerized/system/architecture)
- Flows / topology: [/specs/edge-proxy-uncontainerized/system/runtime-topology](/specs/edge-proxy-uncontainerized/system/runtime-topology)
- Research: [link](/specs/edge-proxy-uncontainerized/research)
- Data model: [link](/specs/edge-proxy-uncontainerized/data-model)
- Quickstart: [link](/specs/edge-proxy-uncontainerized/quickstart)

