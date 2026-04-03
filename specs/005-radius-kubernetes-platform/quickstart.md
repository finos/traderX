# Quickstart: Radius Platform on Kubernetes

## 1) Generate State 005

```bash
bash pipeline/generate-state.sh 005-radius-kubernetes-platform
```

## 2) Start / Verify / Test / Stop (kind)

```bash
./scripts/start-state-005-radius-kubernetes-platform-generated.sh --provider kind
./scripts/status-state-005-radius-kubernetes-platform-generated.sh --provider kind
./scripts/test-state-005-radius-kubernetes-platform.sh http://localhost:8080 traderx kind traderx-state-004
./scripts/stop-state-005-radius-kubernetes-platform-generated.sh --provider kind
```
