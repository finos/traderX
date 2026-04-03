# Research: Tilt Local Dev on Kubernetes

## Objective

Define the transition from state `004` to `006` by adding Tilt-based local development workflows on Kubernetes.

## Inputs Reviewed

- `spec.md`
- `plan.md`
- `tasks.md`
- `system/architecture.md`
- `system/runtime-topology.md`

## Key Decisions

1. Reuse Kubernetes runtime baseline from state `004`.
2. Add a developer inner-loop workflow using Tilt.
3. Preserve functional behavior and external API expectations from predecessor state.
