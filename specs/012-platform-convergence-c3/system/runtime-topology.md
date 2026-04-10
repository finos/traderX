# Runtime Topology: 012-platform-convergence-c3

Parent state: `011-tilt-kubernetes-dev-loop`  
Dotted-line convergence parent: `009-order-management-matcher`

State `011` keeps runtime topology from `010` and serves as the C3 convergence checkpoint.

## Entrypoints

- Browser/UI/API entrypoint remains `http://localhost:8080`.
- Developer loop entrypoint remains Tilt (`tilt up`).

## Components

- Kubernetes runtime + Tilt tooling from state `010`.
- Functional capability level equivalent to C2 (`008`) via lineage through `010`.

## Networking

- Service routes and path prefixes remain unchanged from `010`.
- Dotted-line lineage does not change deploy/runtime wiring.

## Startup / Health Order

- Startup and health checks remain as in `010`.
- This state adds governance/lineage convergence semantics, not runtime topology changes.
