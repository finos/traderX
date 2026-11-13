# Component List

State: `007-observability-lgtm-compose`

| ID | Label | Kind | Description |
| --- | --- | --- | --- |
| `developer` | Developer | actor | Local developer using this state. |
| `app_runtime` | TraderX App Runtime (State 006) | boundary | Baseline containerized TraderX services. |
| `obs_runtime` | Observability Runtime | boundary | LGTM + OTel stack for metrics/logs/traces. |
| `ingress` | NGINX Ingress | service | Edge entrypoint for UI and service proxy. |
| `core_services` | Core Services | service | Account, position, trade, processor, people, reference-data, nats-broker, database, UI. |
| `prometheus` | Prometheus | service | Scrapes probe and collector metrics. |
| `blackbox` | Blackbox Exporter | service | HTTP probe exporter for service availability/latency. |
| `loki` | Loki | service | Log aggregation backend. |
| `promtail` | Promtail | service | Docker log collector to Loki. |
| `tempo` | Tempo | service | Trace backend. |
| `otel` | OpenTelemetry Collector | service | OTLP ingest and telemetry routing. |
| `grafana` | Grafana | service | Unified dashboards for metrics, logs, traces. |
