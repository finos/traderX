# Run From Clone

Prerequisites:
- Docker
- kubectl
- jq
- Kind (default) or Minikube

Start:

```bash
./scripts/start-state-010-kubernetes-runtime-generated.sh
./scripts/start-state-010-kubernetes-runtime-generated.sh --skip-build
# optional:
# ./scripts/start-state-010-kubernetes-runtime-generated.sh --provider minikube --minikube-profile traderx-state-010
```

Endpoints:
- UI / edge: `http://localhost:8080`
- API explorer (edge): `http://localhost:8080/api/docs`
- Edge health: `http://localhost:8080/health`
- Grafana: `http://localhost:8080/grafana` (admin/admin)
- Prometheus: `http://localhost:8080/prometheus`

Status / stop:

```bash
./scripts/status-state-010-kubernetes-runtime-generated.sh
./scripts/stop-state-010-kubernetes-runtime-generated.sh
```

## Stable Entrypoints

Use root wrappers for this generated branch:

```bash
./start-env.sh   # start this state runtime
./status-env.sh  # runtime health/status
./stop-env.sh    # stop runtime
./test-env.sh    # state smoke/validation
```

Wrappers intentionally delegate to numbered state scripts to maximize reuse while keeping clone-first commands stable.
