# Quickstart: Kubernetes Runtime Baseline

## 1) Generate State 009

```bash
bash pipeline/generate-state.sh 009-kubernetes-runtime
```

## 2) Start / Verify / Test / Stop (kind)

```bash
./scripts/start-state-009-kubernetes-runtime-generated.sh --provider kind
./scripts/status-state-009-kubernetes-runtime-generated.sh --provider kind
./scripts/test-state-009-kubernetes-runtime.sh http://localhost:8080 traderx kind traderx-state-009
./scripts/stop-state-009-kubernetes-runtime-generated.sh --provider kind
```
