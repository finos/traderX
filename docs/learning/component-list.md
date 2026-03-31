# Component List

State: `005-radius-kubernetes-platform`

| ID | Label | Kind | Description |
| --- | --- | --- | --- |
| `developer` | Developer | actor | Operates platform/application definitions through Radius. |
| `radius` | Radius Control Plane | platform | Application-centric platform abstraction layer. |
| `appModel` | Radius App Model | component | Declarative app/resource definitions for TraderX. |
| `cluster` | Kubernetes Cluster | boundary | Underlying runtime substrate inherited from state 004. |
| `edge` | NGINX Edge Proxy | gateway | Single browser/API entrypoint. |
| `workloads` | TraderX Workloads | service | Core services remain functionally equivalent to state 004. |
