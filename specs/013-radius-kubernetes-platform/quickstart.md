# Quickstart: Radius Platform on Kubernetes

## 1) Generate State 013

```bash
bash pipeline/generate-state.sh 013-radius-kubernetes-platform
```

## 2) Start / Verify / Test / Stop (kind)

```bash
./scripts/start-state-013-radius-kubernetes-platform-generated.sh --provider kind
./scripts/start-state-013-radius-kubernetes-platform-generated.sh --provider kind --skip-build
./scripts/status-state-013-radius-kubernetes-platform-generated.sh --provider kind
./scripts/test-state-013-radius-kubernetes-platform.sh http://localhost:8080 traderx kind traderx-state-013
./scripts/stop-state-013-radius-kubernetes-platform-generated.sh --provider kind
```
