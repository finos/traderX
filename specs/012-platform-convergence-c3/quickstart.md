# Quickstart: Platform Convergence C3

## 1) Generate State 012

```bash
bash pipeline/generate-state.sh 012-platform-convergence-c3
```

## 2) Start / Verify / Test / Stop (kind)

```bash
./scripts/start-state-012-platform-convergence-c3-generated.sh --provider kind
./scripts/start-state-012-platform-convergence-c3-generated.sh --provider kind --skip-build
./scripts/status-state-012-platform-convergence-c3-generated.sh --provider kind
./scripts/test-state-012-platform-convergence-c3.sh http://localhost:8080 traderx kind traderx-state-012
./scripts/stop-state-012-platform-convergence-c3-generated.sh --provider kind
```
