# Runtime Topology: 012-observability-on-pricing

Parent state: `010-pricing-awareness-market-data`

Describe runtime topology and network/data flow changes introduced by this state.

## Entrypoints

- App ingress: `http://localhost:8080`
- Grafana: `http://localhost:3000`
- Prometheus: `http://localhost:9090`
- Loki: `http://localhost:3100`
- Tempo: `http://localhost:3200`
- OTel Collector health: `http://localhost:13133`
- NATS monitor: `http://localhost:8222/varz`
- Price publisher health: `http://localhost:18100/health`

## Components

- Pricing runtime components from state `010`.
- Added observability components:
  - `grafana`
  - `prometheus`
  - `loki`
  - `tempo`
  - `otel-collector`
  - `blackbox-exporter`
  - `promtail`

## Networking

- Prometheus probes app/pricing/NATS endpoints through blackbox exporter.
- Promtail discovers Docker containers and pushes logs to Loki.
- Grafana queries Prometheus, Loki, and Tempo datasources.
- OTel Collector exposes OTLP receivers for future app instrumentation.

## Startup / Health Order

1. Start pricing runtime services from state `010`.
2. Start observability backends (`loki`, `tempo`, `otel-collector`, `blackbox-exporter`, `prometheus`).
3. Start Grafana after datasources are reachable.
4. Validate pricing flow and observability endpoint health.
