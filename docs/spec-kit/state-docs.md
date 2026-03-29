---
title: State Docs
---

# State Docs

This page is generated from `catalog/state-catalog.json` and links the most important per-state artifacts.

For progression context, see [Visual Learning Paths](/docs/spec-kit/visual-learning-graphs).

## State Catalog

| State | Status | Spec Pack | Architecture | Flows / Topology | Generated Code Branch |
| --- | --- | --- | --- | --- | --- |
| `001-baseline-uncontainerized-parity` | released | [/specs/baseline-uncontainerized-parity](/specs/baseline-uncontainerized-parity) | [/specs/baseline-uncontainerized-parity/system/architecture](/specs/baseline-uncontainerized-parity/system/architecture) | [/specs/baseline-uncontainerized-parity/system/end-to-end-flows](/specs/baseline-uncontainerized-parity/system/end-to-end-flows) | `codex/generated-state-001-baseline-uncontainerized-parity` |
| `002-edge-proxy-uncontainerized` | implemented | [/specs/edge-proxy-uncontainerized](/specs/edge-proxy-uncontainerized) | [/specs/edge-proxy-uncontainerized/system/architecture](/specs/edge-proxy-uncontainerized/system/architecture) | [/specs/edge-proxy-uncontainerized/system/runtime-topology](/specs/edge-proxy-uncontainerized/system/runtime-topology) | `codex/generated-state-002-edge-proxy-uncontainerized` |
| `003-containerized-compose-runtime` | implemented | [/specs/containerized-compose-runtime](/specs/containerized-compose-runtime) | [/specs/containerized-compose-runtime/system/architecture](/specs/containerized-compose-runtime/system/architecture) | [/specs/containerized-compose-runtime/system/runtime-topology](/specs/containerized-compose-runtime/system/runtime-topology) | `codex/generated-state-003-containerized-compose-runtime` |
| `004-kubernetes-runtime` | implemented | [/specs/kubernetes-runtime](/specs/kubernetes-runtime) | [/specs/kubernetes-runtime/system/architecture](/specs/kubernetes-runtime/system/architecture) | [/specs/kubernetes-runtime/system/runtime-topology](/specs/kubernetes-runtime/system/runtime-topology) | `codex/generated-state-004-kubernetes-runtime` |
| `005-radius-kubernetes-platform` | implemented | [/specs/radius-kubernetes-platform](/specs/radius-kubernetes-platform) | [/specs/radius-kubernetes-platform/system/architecture](/specs/radius-kubernetes-platform/system/architecture) | [/specs/radius-kubernetes-platform/system/runtime-topology](/specs/radius-kubernetes-platform/system/runtime-topology) | `codex/generated-state-005-radius-kubernetes-platform` |
| `006-tilt-kubernetes-dev-loop` | planned | [/specs/tilt-kubernetes-dev-loop](/specs/tilt-kubernetes-dev-loop) | [/specs/tilt-kubernetes-dev-loop/system/architecture](/specs/tilt-kubernetes-dev-loop/system/architecture) | [/specs/tilt-kubernetes-dev-loop/system/runtime-topology](/specs/tilt-kubernetes-dev-loop/system/runtime-topology) | `codex/generated-state-006-tilt-kubernetes-dev-loop` |

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
