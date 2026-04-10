# Non-Functional Delta: 012-platform-convergence-c3

Parent state: `011-tilt-kubernetes-dev-loop`

This state preserves C3 convergence semantics on top of state `011`.

## Runtime / Operations

- Runtime substrate remains Kubernetes.
- Runtime entrypoint behavior remains functionally equivalent to state `011`.

## Security / Compliance

- No baseline authn/authz changes introduced.
- Local dev-only orchestration should remain isolated from production deployment definitions.

## Performance / Scalability

- Focus is local developer productivity and turnaround time.
- No change to baseline performance contracts is required.

## Reliability / Observability

- Tilt provides consolidated service logs/status and rapid failure feedback.
- Baseline readiness/health semantics inherited from state `011` remain unchanged.
- Inherited observability entrypoints from state `011` remain required:
  - `http://localhost:8080/grafana`
  - `http://localhost:8080/prometheus`
