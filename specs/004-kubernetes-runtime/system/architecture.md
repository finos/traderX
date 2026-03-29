# Kubernetes Runtime Baseline

Update this model with the authoritative architecture for this state.

- Generated from: `system/architecture.model.json`
- Canonical flows: `system/end-to-end-flows.md`

## Architecture Diagram

```mermaid
flowchart LR
  developer["Developer"]
  runtime["004-kubernetes-runtime Runtime"]
  developer -->|"Runs state"| runtime
```

## Node Catalog

| Node | Kind | Label | Notes |
| --- | --- | --- | --- |
| `developer` | actor | Developer | Local developer using this state. |
| `runtime` | boundary | 004-kubernetes-runtime Runtime | Target runtime for this state. |

