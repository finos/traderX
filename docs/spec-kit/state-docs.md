---
title: State Docs
hide_table_of_contents: true
---

# State Docs

This page is generated from `catalog/state-catalog.json` and links the most important per-state artifacts.

For progression context, see [Visual Learning Paths](/docs/spec-kit/visual-learning-graphs).

## State Catalog

| State | Status | Learning Guide | Spec Pack | Architecture | Flows / Topology | Generated Code Branch |
| --- | --- | --- | --- | --- | --- | --- |
| `001-baseline-uncontainerized-parity` | released | [link](/docs/learning/state-001-baseline-uncontainerized-parity) | [link](/specs/baseline-uncontainerized-parity) | [link](/specs/baseline-uncontainerized-parity/system/architecture) | [link](/specs/baseline-uncontainerized-parity/system/end-to-end-flows) | [code/generated-state-001-baseline-uncontainerized-parity](https://github.com/finos/traderX/tree/code/generated-state-001-baseline-uncontainerized-parity) |
| `002-edge-proxy-uncontainerized` | implemented | [link](/docs/learning/state-002-edge-proxy-uncontainerized) | [link](/specs/edge-proxy-uncontainerized) | [link](/specs/edge-proxy-uncontainerized/system/architecture) | [link](/specs/edge-proxy-uncontainerized/system/runtime-topology) | [code/generated-state-002-edge-proxy-uncontainerized](https://github.com/finos/traderX/tree/code/generated-state-002-edge-proxy-uncontainerized) |
| `003-containerized-compose-runtime` | implemented | [link](/docs/learning/state-003-containerized-compose-runtime) | [link](/specs/containerized-compose-runtime) | [link](/specs/containerized-compose-runtime/system/architecture) | [link](/specs/containerized-compose-runtime/system/runtime-topology) | [code/generated-state-003-containerized-compose-runtime](https://github.com/finos/traderX/tree/code/generated-state-003-containerized-compose-runtime) |
| `004-kubernetes-runtime` | implemented | [link](/docs/learning/state-004-kubernetes-runtime) | [link](/specs/kubernetes-runtime) | [link](/specs/kubernetes-runtime/system/architecture) | [link](/specs/kubernetes-runtime/system/runtime-topology) | [code/generated-state-004-kubernetes-runtime](https://github.com/finos/traderX/tree/code/generated-state-004-kubernetes-runtime) |
| `005-radius-kubernetes-platform` | implemented | [link](/docs/learning/state-005-radius-kubernetes-platform) | [link](/specs/radius-kubernetes-platform) | [link](/specs/radius-kubernetes-platform/system/architecture) | [link](/specs/radius-kubernetes-platform/system/runtime-topology) | [code/generated-state-005-radius-kubernetes-platform](https://github.com/finos/traderX/tree/code/generated-state-005-radius-kubernetes-platform) |
| `006-tilt-kubernetes-dev-loop` | implemented | [link](/docs/learning/state-006-tilt-kubernetes-dev-loop) | [link](/specs/tilt-kubernetes-dev-loop) | [link](/specs/tilt-kubernetes-dev-loop/system/architecture) | [link](/specs/tilt-kubernetes-dev-loop/system/runtime-topology) | [code/generated-state-006-tilt-kubernetes-dev-loop](https://github.com/finos/traderX/tree/code/generated-state-006-tilt-kubernetes-dev-loop) |

## API Explorer by State

- Current API explorer route: [/api](/api)
- Current scope: `001-baseline-uncontainerized-parity`
- Source contracts: `specs/001-baseline-uncontainerized-parity/contracts/**/openapi.yaml`
- Future plan: add per-state API explorer selectors as additional state contract sets are published.

## How This Page Is Maintained

- Source catalog: `catalog/state-catalog.json`
- Regenerate this page:

```bash
node pipeline/generate-state-docs-from-catalog.mjs
```

- State architecture docs are generated from:
  - `specs/<state>/system/architecture.model.json`
- Generate state architecture docs:

```bash
bash pipeline/generate-state-architecture-doc.sh <state-id>
```

- Generate all state architecture docs:

```bash
bash pipeline/generate-all-architecture-docs.sh
```
