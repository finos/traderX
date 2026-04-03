---
title: "State 002: Edge Proxy Uncontainerized"
---

# State 002 Learning Guide

## Position In Learning Graph

- Previous state(s): [001-baseline-uncontainerized-parity](/docs/learning/state-001-baseline-uncontainerized-parity)
- Next state(s): [003-containerized-compose-runtime](/docs/learning/state-003-containerized-compose-runtime)

## Rendered Code

- Generated branch: [code/generated-state-002-edge-proxy-uncontainerized](https://github.com/finos/traderX/tree/code/generated-state-002-edge-proxy-uncontainerized)
- Authoring branch (spec source): [feature/agentic-renovation](https://github.com/finos/traderX/tree/feature/agentic-renovation)

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

