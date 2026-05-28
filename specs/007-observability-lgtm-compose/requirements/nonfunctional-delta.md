# Non-Functional Delta: 007-observability-lgtm-compose

Parent state: `006-messaging-nats-replacement`

Document NFR changes introduced by this state.

## Runtime / Operations

- Add observability services to compose runtime:
  - Grafana (`:3001`, container `3000`)
  - Prometheus (`:9090`)
  - Loki (`:3100`)
  - Tempo (`:3200`)
  - OTel Collector (`:4317`, `:4318`, `:13133`)
  - Blackbox Exporter (`:9115`)
  - Promtail (internal)
- Keep all existing TraderX service ports unchanged from state `006`.

## Security / Compliance

- Grafana dashboards are publicly readable through ingress using anonymous Viewer access for demos.
- Grafana administrator credentials use state-scoped non-`admin/admin` defaults and remain overrideable with `TRADERX_GRAFANA_ADMIN_USER` and `TRADERX_GRAFANA_ADMIN_PASSWORD`.
- Promtail Docker discovery uses a Docker API version exported by the generated runtime harness from the local Docker daemon, with `TRADERX_PROMTAIL_DOCKER_API_VERSION` as the explicit override.
- State is intended for local learning environments, not production deployment.
- As convergence level `C1`, this state requires container build/publish CI with namespace `ghcr.io/finos/traderx-c1/<component>`.
- Generated artifacts must include a GHCR run bundle so users can run the `C1` environment from published images.

## Performance / Scalability

- Prometheus probe interval defaults to 15 seconds to balance signal quality and local resource cost.
- Log scraping uses Docker service discovery and label relabeling for low-friction local operation.

## Reliability / Observability

- Blackbox probe success and latency metrics are available for key TraderX endpoints.
- Spring Boot actuator Prometheus metrics are scraped for all compatible JVM services in this state.
- Prometheus-compatible metrics exposure is a required integration point: if a service supports it, scrape targets and dashboards must be updated in the same change.
- Container logs are queryable in Grafana via Loki.
- Smoke validation must verify Loki-backed dashboard data is non-empty for both total runtime streams and service-filtered panels (for example messaging, pricing pipeline, and control-plane views).
- OTel Collector and Tempo are wired for trace ingestion to support future instrumentation growth.
- Provisioned dashboards provide out-of-the-box visibility for service availability, latency, log throughput, and JVM/service metric health.
