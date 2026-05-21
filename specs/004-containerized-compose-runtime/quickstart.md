# Quickstart: Containerized Compose Runtime

## 1) Generate State 004

```bash
bash pipeline/generate-state.sh 004-containerized-compose-runtime
```

## 2) Start / Verify / Test / Stop

```bash
./scripts/start-state-004-containerized-generated.sh
./scripts/start-state-004-containerized-generated.sh --skip-build
./scripts/status-state-004-containerized-generated.sh
./scripts/test-state-004-containerized.sh
./scripts/stop-state-004-containerized-generated.sh
```
