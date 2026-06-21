# Runtime Topology: 007-observability-lgtm-compose

Parent state: `006-messaging-nats-replacement`

Describe runtime topology and network/data flow changes introduced by this state.

## Entrypoints

- App ingress: `http://localhost:8080`
- Grafana: `http://localhost:3001`
- Grafana through ingress: `http://localhost:8080/grafana/`
- Prometheus: `http://localhost:9090`
- Loki: `http://localhost:3100`
- Tempo: `http://localhost:3200`
- OTel Collector health: `http://localhost:13133`

## Components

- Baseline application components from state `006`.
- Added observability components:
  - `grafana`
  - `prometheus`
  - `loki`
  - `tempo`
  - `otel-collector`
  - `blackbox-exporter`
  - `promtail`

## Networking

- Prometheus probes application endpoints through the compose network via blackbox exporter.
- Prometheus also scrapes Spring Boot actuator metrics (`/actuator/prometheus`) for all compatible services in this state.
- Promtail discovers Docker containers and pushes logs to Loki.
- Promtail receives `TRADERX_PROMTAIL_DOCKER_API_VERSION` from the generated runtime harness; by default the harness detects the local Docker daemon API version.
- Grafana queries Prometheus, Loki, and Tempo datasources.
- Grafana ingress runs from `/grafana/` with anonymous Viewer access enabled and non-`admin/admin` state-scoped administrator defaults.
- OTel Collector exposes OTLP receivers for future app instrumentation.

## Startup / Health Order

1. Start baseline app services from state `006`.
2. Start observability backends (`loki`, `tempo`, `otel-collector`, `blackbox-exporter`, `prometheus`).
3. Start Grafana after datasources are reachable.
4. Validate baseline app flow and observability endpoint health.
