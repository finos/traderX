# Component List

State: `011-tilt-kubernetes-dev-loop`

| ID | Label | Kind | Description |
| --- | --- | --- | --- |
| `developer` | Developer | actor | Iterates locally with fast feedback loops. |
| `tilt` | Tilt Dev Loop | tooling | Build/deploy/log orchestration for local k8s. |
| `cluster` | Kubernetes Cluster | boundary | Underlying runtime substrate inherited from state 010. |
| `edge` | NGINX Edge Proxy | gateway | Single browser/API entrypoint. |
| `workloads` | TraderX Workloads | service | Core services remain functionally equivalent to state 010. |
