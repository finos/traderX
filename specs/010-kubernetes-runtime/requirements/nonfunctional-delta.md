# Non-Functional Delta: 010-kubernetes-runtime

Parent state: `009-order-management-matcher`

This state changes runtime and operations model while keeping baseline functional behavior stable.

## Runtime / Operations

- Local runtime target is Kubernetes (Kind baseline by default, optional Minikube path).
- Generated state includes:
  - Kind cluster config with fixed host port mapping (`8080 -> nodePort 30080`)
  - Kubernetes manifests (namespace, deployments, services, edge-proxy config)
  - Kubernetes observability manifests (Prometheus, Grafana, Loki, Tempo, OpenTelemetry collector, blackbox exporter)
  - Build plan for deterministic local image build/load flow.
- Canonical runtime scripts:
  - `scripts/start-state-010-kubernetes-runtime-generated.sh`
  - `scripts/stop-state-010-kubernetes-runtime-generated.sh`
  - `scripts/status-state-010-kubernetes-runtime-generated.sh`
  - `scripts/test-state-010-kubernetes-runtime.sh`

## Security / Compliance

- No new authn/authz model introduced in this state (intentionally baseline/legacy-like).
- Network surface is reduced to one browser entrypoint (`localhost:8080`) plus internal cluster service networking.

## Deployment Profile Planning

- Kubernetes lineage deploy bundles should use profile `aws-ec2-k8s` (not `aws-ec2-compose`).
- Profile is specification-defined but intentionally disabled until generator support is implemented.
- Enablement requires generated Kubernetes deploy assets, host prerequisite checks, and profile smoke tests.

## Performance / Scalability

- Services run as Kubernetes Deployments with explicit replica counts (default `1` for baseline determinism).
- State prepares topology for later horizontal scaling and autoscaling overlays without changing baseline contracts.

## Reliability / Observability

- Startup scripts gate readiness by waiting for Kubernetes deployment availability and edge health endpoint.
- State status script provides deployment/pod/service visibility plus ingress health probes.
- Inherited observability capabilities from state `009-order-management-matcher` are preserved through ingress-routed endpoints:
  - Grafana: `http://localhost:8080/grafana`
  - Prometheus: `http://localhost:8080/prometheus`
