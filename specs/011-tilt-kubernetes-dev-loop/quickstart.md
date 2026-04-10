# Quickstart: Tilt Local Dev on Kubernetes

## 1) Generate State 011

```bash
bash pipeline/generate-state.sh 011-tilt-kubernetes-dev-loop
```

## 2) Start / Verify / Test / Stop (kind)

```bash
./scripts/start-state-011-tilt-kubernetes-dev-loop-generated.sh --provider kind
./scripts/status-state-011-tilt-kubernetes-dev-loop-generated.sh --provider kind
./scripts/test-state-011-tilt-kubernetes-dev-loop.sh http://localhost:8080 traderx kind traderx-state-009
./scripts/stop-state-011-tilt-kubernetes-dev-loop-generated.sh --provider kind
```
