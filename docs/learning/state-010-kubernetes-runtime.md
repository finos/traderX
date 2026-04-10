---
title: "State 010: Kubernetes Runtime on C2"
---

# State 010 Learning Guide

## Position In Learning Graph

- Previous state(s): [009-order-management-matcher](/docs/learning/state-009-order-management-matcher)
- Dotted-line parent(s): none
- Next state(s): [011-tilt-kubernetes-dev-loop](/docs/learning/state-011-tilt-kubernetes-dev-loop), [013-radius-kubernetes-platform](/docs/learning/state-013-radius-kubernetes-platform)

## Convergence Metadata

- Convergence state: `no`
- Convergence level: `none`
- Lineage role: `canonical`
- Nearest previous convergence: `none`
- Nearest next convergence: `none`

## Rendered Code

- Generated branch: [code/generated-state-010-kubernetes-runtime](https://github.com/finos/traderX/tree/code/generated-state-010-kubernetes-runtime)
- Authoring branch (spec source): [feature/agentic-renovation](https://github.com/finos/traderX/tree/feature/agentic-renovation)

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

