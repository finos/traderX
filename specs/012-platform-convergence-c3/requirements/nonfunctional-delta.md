# Non-Functional Delta: 012-platform-convergence-c3

Parent state: `011-tilt-kubernetes-dev-loop`

This state preserves C3 convergence semantics on top of state `011`.

## Runtime / Operations

- Runtime substrate remains Kubernetes.
- Runtime entrypoint behavior remains functionally equivalent to state `011`.

## Security / Compliance

- No baseline authn/authz changes introduced.
- Local dev-only orchestration should remain isolated from production deployment definitions.
- As convergence level `C3`, this state requires container build/publish CI with namespace `ghcr.io/finos/traderx-c3/<component>`.
- Generated artifacts must include a GHCR run bundle so users can run the `C3` environment from published images.

## Performance / Scalability

- Focus is local developer productivity and turnaround time.
- No change to baseline performance contracts is required.

## Reliability / Observability

- Tilt provides consolidated service logs/status and rapid failure feedback.
- Baseline readiness/health semantics inherited from state `011` include the state `010` Kubernetes readiness preflight: rollout status is necessary but not sufficient, and smoke tests wait for ingress-level service readiness before behavioral assertions.
- Published-image C3 runs on Apple Silicon should expect slower JVM startup under amd64 emulation and use the documented readiness timeout budget before smoke tests or scanner preflights.
- Inherited observability entrypoints from state `011` remain required:
  - `http://localhost:8080/grafana`
  - `http://localhost:8080/prometheus`
