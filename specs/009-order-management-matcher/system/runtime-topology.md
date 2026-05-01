# Runtime Topology: 009-order-management-matcher

Parent state: `008-pricing-awareness-market-data`

Describe runtime topology and network/data flow changes introduced by this state.

## Entrypoints

- App ingress: `http://localhost:8080`
- Grafana: `http://localhost:3001`
- Prometheus: `http://localhost:9090`
- NATS monitor: `http://localhost:8222/varz`
- Order matcher health: `http://localhost:<order-matcher-port>/health`
- Order matcher metrics: `http://localhost:<order-matcher-port>/metrics`

## Components

- Inherits pricing runtime from `008` and observability baseline from `007`.
- Adds order components:
  - `order-matcher` (Java/Spring Boot matching + persistence + metrics)
  - order-management API handlers integrated with backend flow
  - trader UI order ticket + account open-orders blotter
  - Admin UI view for cross-account order operations
- Extends observability concerns:
  - Prometheus target coverage for order matcher endpoints
  - Grafana dashboards for order queue depth, events, and matcher latency
  - Loki log streams for order matcher and admin operations

## Networking

- Admin UI requests order APIs through existing ingress.
- Order matcher writes order lifecycle to shared DB and submits fills through trade-service API.
- Trade processor and position service consume matcher-generated trades via existing integration path.
- Prometheus scrapes order matcher metrics and probes order endpoints via blackbox exporter.
- Prometheus also scrapes Spring Boot actuator metrics (`/actuator/prometheus`) for all compatible services in this state.
- Grafana queries Prometheus/Loki/Tempo for order-management views.

## Startup / Health Order

1. Start inherited state `008` runtime (app + LGTM).
2. Start `order-matcher` and validate `/health` and `/metrics`.
3. Ensure ingress routes order-management APIs and admin UI path.
4. Verify Prometheus discovers order targets and required metric families.
5. Verify Grafana has order-specific dashboards provisioned.
