# Non-Functional Delta: 008-pricing-awareness-market-data

Parent state: `008-pricing-awareness-market-data`

Document NFR changes introduced by this state.

## Runtime / Operations

- Add observability services to pricing runtime:
  - Grafana (`:3000`)
  - Prometheus (`:9090`)
  - Loki (`:3100`)
  - Tempo (`:3200`)
  - OTel Collector (`:4317`, `:4318`, `:13133`)
  - Blackbox Exporter (`:9115`)
  - Promtail (internal)
- Keep all existing TraderX pricing runtime ports unchanged from state `010`.

## Security / Compliance

- No authentication hardening added in this state; Grafana credentials are local-dev defaults (`admin/admin`).
- State is intended for local learning environments, not production deployment.

## Performance / Scalability

- Prometheus probe interval defaults to 15 seconds for stable local workloads.
- Pricing-specific probes include NATS monitor and price-publisher health/quote endpoints.

## Reliability / Observability

- Blackbox probe success and latency metrics cover pricing path and core APIs.
- Container logs are queryable in Grafana via Loki.
- OTel Collector and Tempo are present for trace ingestion and future instrumentation.
- Provisioned dashboards provide pricing + runtime observability out of the box.
