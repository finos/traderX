---
title: State Docs
---

# State Docs

This page links the most important per-state artifacts for architecture, flows, and state definition.

For progression context, see [Visual Learning Paths](/docs/spec-kit/visual-learning-graphs).

## Current Published States

| State | Pack | Architecture | Flows / Topology |
| --- | --- | --- | --- |
| `001-baseline-uncontainerized-parity` | [/specs/baseline-uncontainerized-parity](/specs/baseline-uncontainerized-parity) | [/specs/baseline-uncontainerized-parity/system/architecture](/specs/baseline-uncontainerized-parity/system/architecture) | [/specs/baseline-uncontainerized-parity/system/end-to-end-flows](/specs/baseline-uncontainerized-parity/system/end-to-end-flows) |
| `002-edge-proxy-uncontainerized` | [/specs/edge-proxy-uncontainerized](/specs/edge-proxy-uncontainerized) | [/specs/edge-proxy-uncontainerized/system/architecture](/specs/edge-proxy-uncontainerized/system/architecture) | [/specs/edge-proxy-uncontainerized/system/runtime-topology](/specs/edge-proxy-uncontainerized/system/runtime-topology) |
| `003-containerized-compose-runtime` | [/specs/containerized-compose-runtime](/specs/containerized-compose-runtime) | [/specs/containerized-compose-runtime/system/architecture](/specs/containerized-compose-runtime/system/architecture) | [/specs/containerized-compose-runtime/system/runtime-topology](/specs/containerized-compose-runtime/system/runtime-topology) |

## API Explorer by State

- Current API explorer route: [/api](/api)
- Current scope: `001-baseline-uncontainerized-parity` OpenAPI contracts.
- Future plan: add per-state API explorer selectors as additional state contract sets are published.

## How Architecture Docs Are Maintained

- Architecture docs are generated from state-local spec models:
  - `specs/<state>/system/architecture.model.json`
- Generation command:

```bash
bash pipeline/generate-state-architecture-doc.sh <state-id>
```

- Generate all states:

```bash
bash pipeline/generate-all-architecture-docs.sh
```

This keeps architecture docs aligned with the same spec packs that drive code generation.
