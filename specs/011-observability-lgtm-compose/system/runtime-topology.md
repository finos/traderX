# Runtime Topology: 011-observability-lgtm-compose

Parent state: `003-containerized-compose-runtime`

Describe runtime topology and network/data flow changes introduced by this state.

## Entrypoints

- App ingress: `http://localhost:8080`
- Grafana: `http://localhost:3000`
- Prometheus: `http://localhost:9090`
- Loki: `http://localhost:3100`
- Tempo: `http://localhost:3200`
- OTel Collector health: `http://localhost:13133`

## Components

- Baseline application components from state `003`.
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
- Promtail discovers Docker containers and pushes logs to Loki.
- Grafana queries Prometheus, Loki, and Tempo datasources.
- OTel Collector exposes OTLP receivers for future app instrumentation.

## Startup / Health Order

1. Start baseline app services from state `003`.
2. Start observability backends (`loki`, `tempo`, `otel-collector`, `blackbox-exporter`, `prometheus`).
3. Start Grafana after datasources are reachable.
4. Validate baseline app flow and observability endpoint health.
