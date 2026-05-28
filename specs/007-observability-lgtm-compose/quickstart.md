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

## 4) Inspect Grafana

```bash
# Anonymous Viewer dashboards through ingress:
open http://localhost:8080/grafana/

# Local admin access uses state-scoped defaults printed by the start script:
open http://localhost:3001
```

Override local admin credentials when needed:

```bash
TRADERX_GRAFANA_ADMIN_USER=my-admin \
TRADERX_GRAFANA_ADMIN_PASSWORD='change-me' \
./scripts/start-state-007-observability-lgtm-compose-generated.sh
```

## 5) Stop Runtime

```bash
./scripts/stop-state-007-observability-lgtm-compose-generated.sh
```
