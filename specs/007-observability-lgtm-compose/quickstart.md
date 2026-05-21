# Quickstart: Observability with LGTM on Compose

## 1) Generate This State

```bash
bash pipeline/generate-state.sh 007-observability-lgtm-compose
```

## 2) Start Runtime

```bash
./scripts/start-state-007-observability-lgtm-compose-generated.sh
./scripts/start-state-007-observability-lgtm-compose-generated.sh --skip-build
```

## 3) Run Smoke Tests

```bash
./scripts/test-state-007-observability-lgtm-compose.sh
```

## 4) Stop Runtime

```bash
./scripts/stop-state-007-observability-lgtm-compose-generated.sh
```
