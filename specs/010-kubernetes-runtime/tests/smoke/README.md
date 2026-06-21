# Smoke Tests: 010-kubernetes-runtime

- Primary smoke script: `scripts/test-state-010-kubernetes-runtime.sh`

Minimum checks for this state:

- Kubernetes deployment availability in namespace `traderx`.
- Kubernetes rollout status for generated deployments and Promtail where present.
- Ingress-level readiness checkoff before behavioral smoke assertions:
  - edge `/health` and UI root.
  - reference-data, people-service, account-service, position-service, trade-service, trade-processor, price-publisher, and order-matcher readiness paths.
  - Grafana `/api/health` and Prometheus `/-/ready` through the edge prefix.
- Edge health and UI entrypoint through `http://localhost:8080`.
- Deployed frontend dev-only paths such as `/@vite/client` do not return HTTP 200.
- Baseline API compatibility through edge-prefixed routes:
  - reference-data
  - account-service
  - people-service
  - position-service
  - trade-service (including unknown ticker/account checks).

Readiness timing can be tuned with `TRADERX_SMOKE_READY_TIMEOUT` and `TRADERX_SMOKE_READY_INTERVAL`. The status script exposes the same preflight with:

```bash
./scripts/status-state-010-kubernetes-runtime-generated.sh --provider kind --wait-ready
```
