# Research: Radius Platform on Kubernetes

## Objective

Define the transition from state `004` to `005` by layering Radius platform capabilities on Kubernetes.

## Inputs Reviewed

- `spec.md`
- `plan.md`
- `tasks.md`
- `system/architecture.md`
- `system/runtime-topology.md`

## Key Decisions

1. Preserve Kubernetes runtime semantics from state `004`.
2. Introduce Radius as a platform abstraction without changing core business flows.
3. Keep generated state publishability and compareability with predecessor state.
