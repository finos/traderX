## TraderX State 009 Runtime

This directory defines the compose runtime for:

- `009-order-management-matcher`

It extends pricing + observability runtime with:

- Order matcher service (Spring Boot + DB-backed order persistence)
- Order management APIs (`/order-matcher/orders*`)
- Spring Boot actuator metric scraping (`/actuator/prometheus`) where available
- Provisioned order + Spring dashboards for queue health, lifecycle rates, latency, and JVM/service SLI visibility

Primary endpoints:

- TraderX UI: `http://localhost:8080`
- Grafana (via ingress): `http://localhost:8080/grafana` (admin/admin)
- Grafana (direct): `http://localhost:3001`
- Prometheus: `http://localhost:9090`
- Loki: `http://localhost:3100`
- Tempo: `http://localhost:3200`
- NATS monitor: `http://localhost:8222/varz`
- Price publisher: `http://localhost:18100/health`
- Order matcher: `http://localhost:18110/health`
