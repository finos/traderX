# Smoke Tests: 006-observability-lgtm-compose

- Primary smoke script: `scripts/test-state-006-observability-lgtm-compose.sh`

Implemented smoke checks:

- Runtime starts cleanly with app + observability services.
- Grafana/Prometheus/Loki/Tempo/OTel Collector health endpoints return success.
- Grafana dashboards are provisioned.
- Prometheus blackbox targets are discovered.
- Baseline functional flow from state `003` remains green.
