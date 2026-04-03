# Quickstart: Tilt Local Dev on Kubernetes

## 1) Generate State 006

```bash
bash pipeline/generate-state.sh 006-tilt-kubernetes-dev-loop
```

## 2) Start / Verify / Test / Stop (kind)

```bash
./scripts/start-state-006-tilt-kubernetes-dev-loop-generated.sh --provider kind
./scripts/status-state-006-tilt-kubernetes-dev-loop-generated.sh --provider kind
./scripts/test-state-006-tilt-kubernetes-dev-loop.sh http://localhost:8080 traderx kind traderx-state-004
./scripts/stop-state-006-tilt-kubernetes-dev-loop-generated.sh --provider kind
```
