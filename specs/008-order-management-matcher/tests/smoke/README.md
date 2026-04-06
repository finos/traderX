# Smoke Tests: 008-order-management-matcher

- Primary smoke script: `scripts/test-state-008-order-management-matcher.sh`

Planned smoke checks:

- Runtime starts cleanly with inherited pricing + observability stack.
- Order API health and matcher health endpoints return success.
- Prometheus sees order matcher metrics target.
- Required metrics are present in matcher `/metrics`:
  - `traderx_orders_open_total`
  - `traderx_orders_unfilled_total`
  - `traderx_order_events_total`
  - `traderx_order_match_latency_seconds`
- User journey checks:
  - create order through ingress API
  - query account-filtered open orders list
  - cancel open order via user action endpoint
- Admin journey checks:
  - force-fill open order via admin endpoint
- Matching journey checks:
  - in-the-money order is auto-filled on matcher ticks using quantity policy (`<1000 => full`, `>=1000 => half`)
  - filled order is visible in trades and updates positions for the affected account
- Lifecycle checks:
  - create/cancel/force-fill path updates order counters and open-order gauges.
- Grafana has provisioned order-management dashboards.
