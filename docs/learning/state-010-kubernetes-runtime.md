---
title: "State 010: Kubernetes Runtime on C2"
pagination_prev: null
pagination_next: null
---

# State 010 Learning Guide

<!-- Generated from specs/010-kubernetes-runtime/learning-contract.json; edit the source. -->

## Move the runtime without changing the trading lesson

An application that works on Compose still needs service discovery, readiness and ingress when moved to a cluster. This chapter is for developers learning Kubernetes through a familiar workload: keep the order workflow fixed while investigating its new runtime boundaries.

[How to learn with TraderX states](/docs/learning/how-to-learn)

**Maturity:** implemented. Run the exercises in a disposable local environment; use the quickstart for setup and cleanup.

### Starting point

C2 combines orders, pricing and observability on Compose.

Entry route: **combined**. Bring the knowledge from every declared predecessor.

#### From 009-order-management-matcher

[Predecessor guide](/docs/learning/state-009-order-management-matcher)

- **Carry forward:** Introduce limit orders, matching and fills while keeping orders distinct from executed trades.
- **Why move:** C2 combines orders, pricing and observability on Compose.
- **Add or revise:** Run C2 on Kubernetes and explain ingress, service routing and pod readiness.
- **Evidence to collect:** Runtime objects replace Compose placement while the order lifecycle remains. The namespace and service selectors explain where traffic goes. An unready backend and a missing ingress route require different fixes. Healthy pods alone do not establish working end-to-end routing.
- **Objectives:** `trace-increment`, `interpret-evidence`

| Before | After |
| --- | --- |
| C2 combines orders, pricing and observability on Compose. | Run C2 on Kubernetes and explain ingress, service routing and pod readiness. |

### Concepts before tools

- A pod is a scheduling unit. A Service gives stable routing to selected pods. Readiness determines whether a pod should receive traffic; replicas alone do not make a workflow correct.

**Runtime prerequisites:** Use the state quickstart for tool versions, generation, start and stop commands. Run one local state at a time because ports and generated output directories are shared.

### Learning objectives

- **trace-increment:** Map an ingress request through a Kubernetes Service to ready pods and verify the retained order behavior.
- **interpret-evidence:** Explain the evidence boundary: An unready backend and a missing ingress route require different fixes. Healthy pods alone do not establish working end-to-end routing.

### Guided walkthrough

#### 1. observe (available)

Objectives: `trace-increment`.

Follow the kind quickstart, including the wait-ready status command and smoke test. Use kubectl get pods,svc -n traderx to map one trade request from ingress to its backend. Submit a small order through the UI and compare with C2 behavior.

**Expected observation and meaning:** Runtime objects replace Compose placement while the order lifecycle remains. The namespace and service selectors explain where traffic goes.

Supporting material: [quickstart](/specs/kubernetes-runtime/quickstart) · [architecture](/specs/kubernetes-runtime/system/architecture) · [runtime-topology](/specs/kubernetes-runtime/system/runtime-topology).

#### 2. challenge (available)

Objectives: `interpret-evidence`.

Inspect kubectl describe pod for a service that is starting or unready, or inspect its readiness probe definition when all pods are ready. Compare process state with the readiness condition before diagnosing ingress.

**Expected observation and meaning:** An unready backend and a missing ingress route require different fixes. Healthy pods alone do not establish working end-to-end routing.

Supporting material: [spec](/specs/kubernetes-runtime/spec) · [contract-delta](/specs/kubernetes-runtime/contracts/contract-delta).

### Demonstrate your understanding

**Question (`trace-increment`, `interpret-evidence`):** Which observations separate a scheduling problem from an application routing problem?

**Assessment guidance:** Use pod events/readiness and Service endpoints, then test ingress and the business result. Explain which boundary each observation tests.

### Scope and limitations

- An unready backend and a missing ingress route require different fixes. Healthy pods alone do not establish working end-to-end routing.
- This is an educational local demonstration. Passing its checks does not establish production readiness, financial settlement, or correctness under every failure mode.


## Position In Learning Graph

- Previous state(s): [009-order-management-matcher](/docs/learning/state-009-order-management-matcher)
- Dotted-line parent(s): none
- Next state(s): [011-tilt-kubernetes-dev-loop](/docs/learning/state-011-tilt-kubernetes-dev-loop)

## Convergence Metadata

- Convergence state: `no`
- Convergence level: `none`
- Lineage role: `canonical`
- Nearest previous convergence: `none`
- Nearest next convergence: `none`

## Rendered Code

- Generated branch: [code/generated-state-010-kubernetes-runtime](https://github.com/finos/traderX/tree/code/generated-state-010-kubernetes-runtime)
- Authoring branch (spec source): [main](https://github.com/finos/traderX/tree/main)

## Code Comparison With Previous State

- Compare against `009-order-management-matcher`: [code/generated-state-009-order-management-matcher...code/generated-state-010-kubernetes-runtime](https://github.com/finos/traderX/compare/code%2Fgenerated-state-009-order-management-matcher...code%2Fgenerated-state-010-kubernetes-runtime)

## Plain-English Code Delta

- **Added:** No new user-facing domain functionality.
- **Changed:** Runtime substrate changes from Docker Compose to Kubernetes.
- **Changed:** Browser/API entry remains single-origin (`http://localhost:8080`) through an NGINX edge proxy service.
- **Removed:** No functional endpoints removed.
- **Flow Impact:** F1 Place Trade: unchanged behavior; routed through Kubernetes edge proxy.
- **Flow Impact:** F2 View Positions: unchanged behavior; data path unchanged.
- **Flow Impact:** F3 Account/User lookups: unchanged behavior; cross-service validation unchanged.
- **Flow Impact:** F4 Reference Data lookup: unchanged behavior; ticker validation unchanged.

## Run This State

```bash
./scripts/start-state-010-kubernetes-runtime-generated.sh
```

## Canonical Spec Links

- State spec pack: [/specs/kubernetes-runtime](/specs/kubernetes-runtime)
- Architecture: [/specs/kubernetes-runtime/system/architecture](/specs/kubernetes-runtime/system/architecture)
- Flows / topology: [/specs/kubernetes-runtime/system/runtime-topology](/specs/kubernetes-runtime/system/runtime-topology)
- Research: [link](/specs/kubernetes-runtime/research)
- Data model: [link](/specs/kubernetes-runtime/data-model)
- Quickstart: [link](/specs/kubernetes-runtime/quickstart)

