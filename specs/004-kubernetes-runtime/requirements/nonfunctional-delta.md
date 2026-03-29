# Non-Functional Delta: 004-kubernetes-runtime

Parent state: `003-containerized-compose-runtime`

This state changes runtime and operations model while keeping baseline functional behavior stable.

## Runtime / Operations

- Local runtime target is Kubernetes (Kind baseline by default, optional Minikube path).
- Generated state includes:
  - Kind cluster config with fixed host port mapping (`8080 -> nodePort 30080`)
  - Kubernetes manifests (namespace, deployments, services, edge-proxy config)
  - Build plan for deterministic local image build/load flow.
- Canonical runtime scripts:
  - `scripts/start-state-004-kubernetes-generated.sh`
  - `scripts/stop-state-004-kubernetes-generated.sh`
  - `scripts/status-state-004-kubernetes-generated.sh`
  - `scripts/test-state-004-kubernetes-runtime.sh`

## Security / Compliance

- No new authn/authz model introduced in this state (intentionally baseline/legacy-like).
- Network surface is reduced to one browser entrypoint (`localhost:8080`) plus internal cluster service networking.

## Performance / Scalability

- Services run as Kubernetes Deployments with explicit replica counts (default `1` for baseline determinism).
- State prepares topology for later horizontal scaling and autoscaling overlays without changing baseline contracts.

## Reliability / Observability

- Startup scripts gate readiness by waiting for Kubernetes deployment availability and edge health endpoint.
- State status script provides deployment/pod/service visibility plus ingress health probes.
