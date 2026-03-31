# Non-Functional Delta: 005-radius-kubernetes-platform

Parent state: `004-kubernetes-runtime`

This state layers Radius platform abstractions on top of the Kubernetes baseline from state `004`.

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
- Application health/readiness behavior remains inherited from Kubernetes state `004`.
