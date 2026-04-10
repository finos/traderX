# Feature Pack 011: Tilt Local Dev on Kubernetes

Status: Implemented  
Track: `devex`  
Previous state: `010-kubernetes-runtime`

This pack defines the Tilt developer-loop state on top of the Kubernetes runtime baseline.

Primary intent:

- add Tilt-based local development automation on top of Kubernetes baseline,
- preserve contracts and runtime semantics from state `010-kubernetes-runtime`,
- keep this path independent from the optional Radius branch (`013-radius-kubernetes-platform`).

Core artifacts:

- `spec.md`
- `requirements/functional-delta.md`
- `requirements/nonfunctional-delta.md`
- `contracts/contract-delta.md`
- `system/architecture.model.json`
- `system/runtime-topology.md`
- `generation/generation-hook.md`
- `tests/smoke/README.md`

Runtime entrypoints:

- `./scripts/start-state-011-tilt-kubernetes-dev-loop-generated.sh`
- `./scripts/status-state-011-tilt-kubernetes-dev-loop-generated.sh`
- `./scripts/test-state-011-tilt-kubernetes-dev-loop.sh`
- `./scripts/stop-state-011-tilt-kubernetes-dev-loop-generated.sh`
