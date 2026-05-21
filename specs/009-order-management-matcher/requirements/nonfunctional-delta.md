# Non-Functional Delta: 009-order-management-matcher

Parent state: `008-pricing-awareness-market-data`

Document NFR changes introduced by this state.

## Runtime / Operations

- Keep LGTM stack from `006` (Grafana, Prometheus, Loki, Tempo, OTel Collector, Promtail, Blackbox Exporter).
- Add order management runtime components:
  - `order-matcher` service (Java 21 / Spring Boot)
  - order-management API endpoints integrated with existing ingress
  - admin UI route under existing Angular app
- Add health and probe targets for order-management endpoints in Prometheus blackbox configs.

## Security / Compliance

- No auth/RBAC hardening introduced in this state; admin view remains local-dev demonstration scope.
- Operational actions (cancel/force-fill) must be auditable via structured logs and traceable order IDs.
- Order data must remain durable across order-matcher process/container restarts while the shared database remains available.
- As convergence level `C2`, this state requires container build/publish CI with namespace `ghcr.io/finos/traderx-c2/<component>`.
- Generated artifacts must include a GHCR run bundle so users can run the `C2` environment from published images.

## Performance / Scalability

- Order open/unfilled gauge updates should be reflected in metrics within one publish cycle of matcher processing.
- Matcher latency histogram captures time from order eligible-for-match to fill publication for local performance baselining.
- Dashboard queries default to short-range windows suitable for active dev loops (5m/15m).
- Realtime blotter UIs should avoid periodic REST polling for incremental changes; push streams are the primary update path after REST bootstrap.

## Reliability / Observability

- Order-management components expose Prometheus metrics and `/health` endpoints.
- Prometheus scrape coverage is mandatory for all services in this state that expose Prometheus-compatible metrics (including `order-matcher` and compatible JVM services via `/actuator/prometheus`).
- Required order metrics:
  - `traderx_orders_open_total` (gauge): total open, unfilled orders.
  - `traderx_orders_unfilled_total` (gauge): open + partially filled orders awaiting completion.
  - `traderx_orders_pending_by_side` (gauge with `side` label): pending buy/sell distribution.
  - `traderx_order_events_total` (counter with `event` label): create, partial_fill, fill, cancel, reject, force_fill.
  - `traderx_order_match_latency_seconds` (histogram): matcher latency distribution.
  - `traderx_order_book_age_seconds` (histogram): order time-in-book before terminal state.
- Grafana includes order observability dashboards with panels for:
  - current open/unfilled orders,
  - fill/cancel/reject/force-fill rates,
  - matcher latency percentiles,
  - order-management error logs,
  - JVM/service SLI panels (request rate, latency percentiles, and scrape target health) for compatible services.
- Smoke tests assert metrics endpoint availability and non-empty response for required metric families.
