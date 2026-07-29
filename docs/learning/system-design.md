# System Design

State: `012-platform-convergence-c3`

## Design Intent

State 012 is the C3 convergence checkpoint: Kubernetes + Tilt platform profile on top of C2 functional behavior.

## Runtime Topology / Flow (Spec Extract)

# Runtime Topology: 012-platform-convergence-c3

Parent state: `011-tilt-kubernetes-dev-loop`  
Dotted-line convergence parent: `009-order-management-matcher`

State `012` keeps runtime topology from `011` and serves as the C3 convergence checkpoint.

## Entrypoints

- Browser/UI/API entrypoint remains `http://localhost:8080`.
- Developer loop entrypoint remains Tilt (`tilt up`).

## Components

- Kubernetes runtime + Tilt tooling from state `011`.
- Functional capability level equivalent to C2 (`009`) via lineage through `011`.

## Networking

- Service routes and path prefixes remain unchanged from `011`.
- Dotted-line lineage does not change deploy/runtime wiring.

## Startup / Health Order

- Startup and health checks remain as in `011`.
- This state adds governance/lineage convergence semantics, not runtime topology changes.
