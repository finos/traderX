---
title: "State 001: Simple App - Base Uncontainerized App"
---

# State 001 Learning Guide

## Position In Learning Graph

- Previous state(s): none
- Next state(s): [002-edge-proxy-uncontainerized](/docs/learning/state-002-edge-proxy-uncontainerized)

## Rendered Code

- Generated branch: [code/generated-state-001-baseline-uncontainerized-parity](https://github.com/finos/traderX/tree/code/generated-state-001-baseline-uncontainerized-parity)
- Authoring branch (spec source): [feature/agentic-renovation](https://github.com/finos/traderX/tree/feature/agentic-renovation)

## Code Comparison With Previous State

- No previous-state compare link for this state.

## Plain-English Code Delta

- **Code focus:** Establishes the full baseline service set and Angular UI in a local multi-process runtime.
- **Runtime behavior:** Uses explicit host ports and direct cross-origin service calls.
- **Learning takeaway:** This is the reference implementation all later state diffs are measured against.

## Run This State

```bash
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./scripts/start-base-uncontainerized-generated.sh
```

## Canonical Spec Links

- State spec pack: [/specs/baseline-uncontainerized-parity](/specs/baseline-uncontainerized-parity)
- Architecture: [/specs/baseline-uncontainerized-parity/system/architecture](/specs/baseline-uncontainerized-parity/system/architecture)
- Flows / topology: [/specs/baseline-uncontainerized-parity/system/end-to-end-flows](/specs/baseline-uncontainerized-parity/system/end-to-end-flows)
- Research: [link](/specs/baseline-uncontainerized-parity/research)
- Data model: [link](/specs/baseline-uncontainerized-parity/data-model)
- Quickstart: [link](/specs/baseline-uncontainerized-parity/quickstart)

