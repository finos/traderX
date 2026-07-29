## TraderX State 007 Runtime

This directory defines the compose runtime for:

- `007-observability-lgtm-compose`

It extends the containerized stack with:

- OpenTelemetry Collector
- Prometheus
- Loki
- Grafana
- Tempo
- Promtail
- Blackbox Exporter
- Spring Boot actuator metric scraping (`/actuator/prometheus`) where available
- Provisioned Spring dashboards for request/latency, JVM health, and SLI trend visibility

Primary endpoints:

- TraderX UI: `http://localhost:8080`
- Grafana dashboards (via ingress): `http://localhost:8080/grafana/`
- Grafana (direct): `http://localhost:3001`
- Prometheus: `http://localhost:9090`
- Loki: `http://localhost:3100`
- Tempo: `http://localhost:3200`
- OTel Collector health: `http://localhost:13133`

Grafana access:

- Dashboards are anonymous Viewer surfaces through ingress for demos.
- Local admin access is available at the direct Grafana URL.
- The generated start script prints the active admin credential on startup.
- Defaults are state-scoped: `TRADERX_GRAFANA_ADMIN_USER` falls back to `traderx-admin`; `TRADERX_GRAFANA_ADMIN_PASSWORD` falls back to `traderx-state-007`.
- Override those values before startup for any shared or long-lived environment.
