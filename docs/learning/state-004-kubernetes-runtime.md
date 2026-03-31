---
title: "State 004: Kubernetes Runtime Baseline"
---

# State 004 Learning Guide

## Position In Learning Graph

- Previous state(s): [003-containerized-compose-runtime](/docs/learning/state-003-containerized-compose-runtime)
- Next state(s): [005-radius-kubernetes-platform](/docs/learning/state-005-radius-kubernetes-platform), [006-tilt-kubernetes-dev-loop](/docs/learning/state-006-tilt-kubernetes-dev-loop)

## Rendered Code

- Generated branch: [code/generated-state-004-kubernetes-runtime](https://github.com/finos/traderX/tree/code/generated-state-004-kubernetes-runtime)
- Authoring branch (spec source): [feature/agentic-renovation](https://github.com/finos/traderX/tree/feature/agentic-renovation)

## Code Comparison With Previous State

- Compare against `003-containerized-compose-runtime`: [code/generated-state-003-containerized-compose-runtime...code/generated-state-004-kubernetes-runtime](https://github.com/finos/traderX/compare/code%2Fgenerated-state-003-containerized-compose-runtime...code%2Fgenerated-state-004-kubernetes-runtime)

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
./scripts/start-state-004-kubernetes-generated.sh
```

## Canonical Spec Links

- State spec pack: [/specs/kubernetes-runtime](/specs/kubernetes-runtime)
- Architecture: [/specs/kubernetes-runtime/system/architecture](/specs/kubernetes-runtime/system/architecture)
- Flows / topology: [/specs/kubernetes-runtime/system/runtime-topology](/specs/kubernetes-runtime/system/runtime-topology)

