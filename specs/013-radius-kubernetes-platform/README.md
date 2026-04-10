# Feature Pack 012: Radius Platform on Kubernetes

Status: Implemented  
Track: `devex`  
Lineage role: `optional`  
Previous state: `010-kubernetes-runtime`

This pack defines the optional Radius platform branch. It is intentionally independent from the Tilt path (`010`).

Primary intent:

- add Radius application model and deployment abstractions on top of Kubernetes baseline,
- keep service contracts and functional behavior stable,
- make platform concerns explicit as NFR deltas.

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

- `./scripts/start-state-013-radius-kubernetes-platform-generated.sh`
- `./scripts/status-state-013-radius-kubernetes-platform-generated.sh`
- `./scripts/test-state-013-radius-kubernetes-platform.sh`
- `./scripts/stop-state-013-radius-kubernetes-platform-generated.sh`
