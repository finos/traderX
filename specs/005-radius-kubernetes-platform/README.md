# Feature Pack 005: Radius Platform on Kubernetes

Status: Planned
Track: `devex`
Previous state: `004-kubernetes-runtime`

This pack defines a platform-layer state that branches directly from `004-kubernetes-runtime`.

It is intentionally independent from state `006` (Tilt dev loop).

Primary intent:

- add Radius application model and deployment abstractions on top of Kubernetes baseline,
- keep baseline service contracts and behavior stable,
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
