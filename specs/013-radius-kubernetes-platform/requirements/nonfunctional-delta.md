# Non-Functional Delta: 013-radius-kubernetes-platform

Parent state: `012-platform-convergence-c3`

This state layers Radius platform abstractions on top of the Kubernetes baseline from state `012`.

## Runtime / Operations

- Runtime substrate remains Kubernetes.
- Deployment model shifts to Radius application/resource definitions.
- Operator workflow targets Radius-first deployment primitives.

## Security / Compliance

- No authn/authz model change is required in this state by default.
- Platform policy controls can be attached through Radius environment/application boundaries.

## Performance / Scalability

- Scaling behavior remains Kubernetes-native unless overridden through Radius-managed policy.
- No baseline performance contract changes are introduced.

## Reliability / Observability

- Radius resource model adds stronger platform-level dependency visibility.
- Application health/readiness behavior remains inherited from Kubernetes state `012`.
- Inherited observability entrypoints from state `012` remain required:
  - `http://localhost:8080/grafana`
  - `http://localhost:8080/prometheus`
