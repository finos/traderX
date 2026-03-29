# Feature Pack 006: Tilt Local Dev on Kubernetes

Status: Planned
Track: `devex`
Previous state: `004-kubernetes-runtime`

This pack defines a developer-loop state that branches directly from `004-kubernetes-runtime`.

It is intentionally independent from state `005` (Radius platform path).

Primary intent:

- add Tilt-based local development automation on top of Kubernetes baseline,
- preserve baseline contracts and runtime semantics from state `004`,
- optimize local inner-loop feedback without requiring Radius.

Core artifacts:

- `spec.md`
- `requirements/functional-delta.md`
- `requirements/nonfunctional-delta.md`
- `contracts/contract-delta.md`
- `system/architecture.model.json`
- `system/runtime-topology.md`
- `generation/generation-hook.md`
- `tests/smoke/README.md`
