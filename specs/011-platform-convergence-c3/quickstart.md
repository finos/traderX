# Quickstart: Platform Convergence C3

## 1) Generate State 006

```bash
bash pipeline/generate-state.sh 011-platform-convergence-c3
```

## 2) Start / Verify / Test / Stop (kind)

```bash
./scripts/start-state-011-platform-convergence-c3-generated.sh --provider kind
./scripts/status-state-011-platform-convergence-c3-generated.sh --provider kind
./scripts/test-state-011-platform-convergence-c3.sh http://localhost:8080 traderx kind traderx-state-004
./scripts/stop-state-011-platform-convergence-c3-generated.sh --provider kind
```
