# Quickstart: Kubernetes Runtime Baseline

## 1) Generate State 010

```bash
bash pipeline/generate-state.sh 010-kubernetes-runtime
```

## 2) Start / Verify / Test / Stop (kind)

```bash
./scripts/start-state-010-kubernetes-runtime-generated.sh --provider kind
./scripts/start-state-010-kubernetes-runtime-generated.sh --provider kind --skip-build
./scripts/status-state-010-kubernetes-runtime-generated.sh --provider kind
./scripts/status-state-010-kubernetes-runtime-generated.sh --provider kind --wait-ready
./scripts/test-state-010-kubernetes-runtime.sh http://localhost:8080 traderx kind traderx-state-010
./scripts/stop-state-010-kubernetes-runtime-generated.sh --provider kind
```
