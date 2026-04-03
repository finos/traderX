# Quickstart: Kubernetes Runtime Baseline

## 1) Generate State 004

```bash
bash pipeline/generate-state.sh 004-kubernetes-runtime
```

## 2) Start / Verify / Test / Stop (kind)

```bash
./scripts/start-state-004-kubernetes-generated.sh --provider kind
./scripts/status-state-004-kubernetes-generated.sh --provider kind
./scripts/test-state-004-kubernetes-runtime.sh http://localhost:8080 traderx kind traderx-state-004
./scripts/stop-state-004-kubernetes-generated.sh --provider kind
```
