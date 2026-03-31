# Run From Clone

Prerequisites:
- Docker
- kubectl
- jq
- Kind (default) or Minikube

Start:

```bash
./scripts/start-state-004-kubernetes-generated.sh
# optional:
# ./scripts/start-state-004-kubernetes-generated.sh --provider minikube --minikube-profile traderx-state-004
```

Endpoints:
- UI / edge: `http://localhost:8080`
- Edge health: `http://localhost:8080/health`

Status / stop:

```bash
./scripts/status-state-004-kubernetes-generated.sh
./scripts/stop-state-004-kubernetes-generated.sh
```
