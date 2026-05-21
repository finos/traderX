# Research: Kubernetes Runtime Baseline

## Objective

Define the transition from state `009` to `010` by introducing Kubernetes runtime deployment.

## Inputs Reviewed

- `spec.md`
- `plan.md`
- `tasks.md`
- `system/architecture.md`
- `system/runtime-topology.md`

## Key Decisions

1. Keep state `009` behavior while changing orchestration to Kubernetes.
2. Support local developer cluster workflows with kind/minikube-compatible manifests.
3. Keep ingress-based access patterns stable for UI and APIs.
