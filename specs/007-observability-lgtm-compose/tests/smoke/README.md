# Smoke Tests: 007-observability-lgtm-compose

- Primary smoke script: `scripts/test-state-007-observability-lgtm-compose.sh`

Implemented smoke checks:

- Runtime starts cleanly with app + observability services.
- Grafana/Prometheus/Loki/Tempo/OTel Collector health endpoints return success.
- Grafana dashboards are provisioned.
- Grafana Loki datasource returns non-empty runtime log content in dashboard query windows.
- Grafana Loki service-filtered queries (messaging/pipeline/control-plane) return non-empty content.
- Prometheus blackbox targets are discovered.
- Spring actuator scrape targets are discovered and healthy.
- Spring services expose `/actuator/prometheus` on service ports (`18088`, `18090`, `18091`, `18092`).
- Prometheus query for `http_server_requests_seconds_count` under `job="traderx-spring-boot-actuator"` returns samples.
- Baseline functional flow from state `006` remains green.
