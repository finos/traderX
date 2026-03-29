# Feature Pack 004: Kubernetes Runtime Baseline

Status: Implemented
Track: `devex`
Previous state: `003-containerized-compose-runtime`

This pack defines the Kubernetes runtime state after `003-containerized-compose-runtime`.

Primary intent:

- capture explicit requirement deltas for this transition,
- define Kubernetes architecture/runtime topology updates for this state,
- keep generation fully spec-first,
- support local developer runtime on Kind (default) and Minikube (optional),
- publish a reproducible generated snapshot branch when implemented.

Core artifacts:

- `spec.md`
- `requirements/functional-delta.md`
- `requirements/nonfunctional-delta.md`
- `contracts/contract-delta.md`
- `system/architecture.model.json`
- `system/runtime-topology.md`
- `system/kubernetes-runtime.spec.json`
- `system/nginx-edge.conf`
- `generation/generation-hook.md`
- `tests/smoke/README.md`
