# Research: Edge Proxy Uncontainerized

## Objective

Define the transition from state `001` to `002` by introducing a single edge entrypoint while preserving baseline service behavior.

## Inputs Reviewed

- `spec.md`
- `plan.md`
- `tasks.md`
- `system/architecture.md`
- `system/runtime-topology.md`

## Key Decisions

1. Keep backend services uncontainerized and preserve baseline ports.
2. Route browser traffic through one edge proxy origin.
3. Keep generation patch-based from the state `001` baseline output.
