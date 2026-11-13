# Component List

State: `012-platform-convergence-c3`

| ID | Label | Kind | Description |
| --- | --- | --- | --- |
| `developer` | Developer | actor | Iterates locally with fast feedback loops. |
| `tilt` | Tilt Dev Loop | tooling | Build/deploy/log orchestration for local k8s. |
| `cluster` | Kubernetes Cluster | boundary | Underlying runtime substrate inherited from state 011. |
| `edge` | NGINX Edge Proxy | gateway | Single browser/API entrypoint. |
| `workloads` | TraderX Workloads | service | Core services remain functionally equivalent to state 009 (C2), carried through state 012 lineage. |
