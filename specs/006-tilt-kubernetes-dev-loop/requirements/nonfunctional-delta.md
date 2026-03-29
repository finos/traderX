# Non-Functional Delta: 006-tilt-kubernetes-dev-loop

Parent state: `004-kubernetes-runtime`

This state adds local development loop automation on top of Kubernetes baseline state `004`.

## Runtime / Operations

- Runtime substrate remains Kubernetes.
- Developer workflow is driven by Tilt (live update/build/deploy loop).
- Runtime entrypoint behavior remains functionally equivalent to state `004`.

## Security / Compliance

- No baseline authn/authz changes introduced.
- Local dev-only orchestration should remain isolated from production deployment definitions.

## Performance / Scalability

- Focus is local developer productivity and turnaround time.
- No change to baseline performance contracts is required.

## Reliability / Observability

- Tilt provides consolidated service logs/status and rapid failure feedback.
- Baseline readiness/health semantics inherited from state `004` remain unchanged.
