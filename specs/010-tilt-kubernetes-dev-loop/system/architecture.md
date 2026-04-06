# Architecture (State 010 Tilt Local Dev on Kubernetes)

State 010 preserves state 009 Kubernetes runtime while introducing Tilt for local developer automation.

- Inherits architectural baseline from: `009-kubernetes-runtime`
- Generated from: `system/architecture.model.json`
- Canonical flows: `../001-baseline-uncontainerized-parity/system/end-to-end-flows.md`

## Entry Points

- `edge-proxy`: `http://localhost:8080`
- `tilt-ui`: `http://localhost:10350`

## Architecture Diagram

```mermaid
flowchart LR
  developer["Developer"]
  tilt["Tilt Dev Loop"]
  cluster["Kubernetes Cluster"]
  edge["NGINX Edge Proxy"]
  workloads["TraderX Workloads"]
  developer -->|"Runs tilt up"| tilt
  tilt -->|"Applies k8s resources"| cluster
  cluster -->|"Runs ingress"| edge
  edge -->|"Routes UI/API/WebSocket traffic"| workloads
```

## Node Catalog

| Node | Kind | Label | Notes |
| --- | --- | --- | --- |
| `developer` | actor | Developer | Iterates locally with fast feedback loops. |
| `tilt` | tooling | Tilt Dev Loop | Build/deploy/log orchestration for local k8s. |
| `cluster` | boundary | Kubernetes Cluster | Underlying runtime substrate inherited from state 009. |
| `edge` | gateway | NGINX Edge Proxy | Single browser/API entrypoint. |
| `workloads` | service | TraderX Workloads | Core services remain functionally equivalent to state 009. |

## State Notes

- State 010 is a sibling branch of state 012; both inherit from state 009.
- Primary delta is developer workflow/tooling, not platform abstraction.

