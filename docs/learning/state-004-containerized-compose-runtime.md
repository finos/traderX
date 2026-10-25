---
title: "State 004: Containerized Compose Runtime (NGINX Ingress)"
pagination_prev: null
pagination_next: null
---

# State 004 Learning Guide

<!-- Generated from specs/004-containerized-compose-runtime/learning-contract.json; edit the source. -->

## Package the same application reproducibly

Installing every service runtime by hand makes an application hard to reproduce. For developers familiar with the host-based stack, this chapter packages the same workflow in containers and examines the gap between a process starting and a service being ready.

[How to learn with TraderX states](/docs/learning/how-to-learn)

**Maturity:** implemented. Run the exercises in a disposable local environment; use the quickstart for setup and cleanup.

### Starting point

The harness and proxied application depend on host-installed service runtimes.

Entry route: **combined**. Bring the knowledge from every declared predecessor.

#### From 003-agentic-harness-foundation

[Predecessor guide](/docs/learning/state-003-agentic-harness-foundation)

- **Carry forward:** Add generated instructions, architecture context and contributor guidance for repeatable agent-assisted work.
- **Why move:** The harness and proxied application depend on host-installed service runtimes.
- **Add or revise:** Run the application as Compose services behind NGINX and distinguish process startup from readiness.
- **Evidence to collect:** The business workflow is retained while process placement changes. Container state, service readiness and successful booking are three different observations. A running container can still be unavailable during initialization. Recovery of a read route does not prove that an uncertain write failed.
- **Objectives:** `trace-increment`, `interpret-evidence`

| Before | After |
| --- | --- |
| The harness and proxied application depend on host-installed service runtimes. | Run the application as Compose services behind NGINX and distinguish process startup from readiness. |

### Concepts before tools

- An image packages a process environment. A container runs it. Compose networking uses service names; localhost inside a container refers to that container.

**Runtime prerequisites:** Use the state quickstart for tool versions, generation, start and stop commands. Run one local state at a time because ports and generated output directories are shared.

### Learning objectives

- **trace-increment:** Map the retained trade workflow to Compose services and distinguish container state, readiness and a successful business result.
- **interpret-evidence:** Explain the evidence boundary: A running container can still be unavailable during initialization. Recovery of a read route does not prove that an uncertain write failed.

### Guided walkthrough

#### 1. observe (available)

Objectives: `trace-increment`.

Generate and start the Compose state using the quickstart. Run its status and smoke commands. Compare the Compose service names, exposed ports and dependencies with the topology, then submit a small trade through ingress.

**Expected observation and meaning:** The business workflow is retained while process placement changes. Container state, service readiness and successful booking are three different observations.

Supporting material: [quickstart](/specs/containerized-compose-runtime/quickstart) · [architecture](/specs/containerized-compose-runtime/system/architecture) · [runtime-topology](/specs/containerized-compose-runtime/system/runtime-topology).

#### 2. challenge (available)

Objectives: `interpret-evidence`.

In the disposable local stack, restart one application container identified in the generated Compose file. Watch status and retry a read through ingress after readiness returns; do not blindly resubmit a timed-out trade.

**Expected observation and meaning:** A running container can still be unavailable during initialization. Recovery of a read route does not prove that an uncertain write failed.

Supporting material: [spec](/specs/containerized-compose-runtime/spec).

### Demonstrate your understanding

**Question (`trace-increment`, `interpret-evidence`):** Why can Compose report running while the browser still receives an error?

**Assessment guidance:** Explain readiness and upstream dependencies using the restarted service. Show the later successful read and separately verify any uncertain trade.

### Scope and limitations

- A running container can still be unavailable during initialization. Recovery of a read route does not prove that an uncertain write failed.
- This is an educational local demonstration. Passing its checks does not establish production readiness, financial settlement, or correctness under every failure mode.


## Position In Learning Graph

- Previous state(s): [003-agentic-harness-foundation](/docs/learning/state-003-agentic-harness-foundation)
- Dotted-line parent(s): none
- Next state(s): [005-postgres-database-replacement](/docs/learning/state-005-postgres-database-replacement)

## Convergence Metadata

- Convergence state: `yes`
- Convergence level: `C0`
- Lineage role: `canonical`
- Nearest previous convergence: `none`
- Nearest next convergence: [007-observability-lgtm-compose](/docs/learning/state-007-observability-lgtm-compose)

## Rendered Code

- Generated branch: [code/generated-state-004-containerized-compose-runtime](https://github.com/finos/traderX/tree/code/generated-state-004-containerized-compose-runtime)
- Authoring branch (spec source): [main](https://github.com/finos/traderX/tree/main)

## Code Comparison With Previous State

- Compare against `003-agentic-harness-foundation`: [code/generated-state-003-agentic-harness-foundation...code/generated-state-004-containerized-compose-runtime](https://github.com/finos/traderX/compare/code%2Fgenerated-state-003-agentic-harness-foundation...code%2Fgenerated-state-004-containerized-compose-runtime)

## Plain-English Code Delta

- **Code focus:** Adds Dockerfiles and Compose assembly for all baseline services.
- **Runtime behavior:** Keeps behavior from state 002 but moves orchestration to containers.
- **Learning takeaway:** Establishes the containerized baseline that other architecture branches build from.

## Run This State

```bash
./scripts/start-state-004-containerized-generated.sh
```

## Canonical Spec Links

- State spec pack: [/specs/containerized-compose-runtime](/specs/containerized-compose-runtime)
- Architecture: [/specs/containerized-compose-runtime/system/architecture](/specs/containerized-compose-runtime/system/architecture)
- Flows / topology: [/specs/containerized-compose-runtime/system/runtime-topology](/specs/containerized-compose-runtime/system/runtime-topology)
- Research: [link](/specs/containerized-compose-runtime/research)
- Data model: [link](/specs/containerized-compose-runtime/data-model)
- Quickstart: [link](/specs/containerized-compose-runtime/quickstart)

