# Contract Delta: 009-order-management-matcher

Parent state: `008-pricing-awareness-market-data`

Document any API/event/schema changes for this state.

## OpenAPI Changes

- Add order-management endpoints (exact path naming finalized in implementation):
  - `POST /orders` (create order)
  - `GET /orders` (query/filter orders)
  - `GET /orders/{orderId}` (order details)
  - `POST /orders/{orderId}/cancel` (cancel order)
  - `POST /orders/{orderId}/force-fill` (admin action)
- Add matcher/admin health endpoint:
  - `GET /order-matcher/health`
- Add matcher metrics endpoint:
  - `GET /order-matcher/metrics` (Prometheus text exposition)

## Integration Contract Changes

- Order fills must submit trades via existing trade-service API:
  - `POST /trade-service/trade/` (through ingress) or `POST /trade/` (service internal path)
- Position/trade persistence contract remains the existing trade pipeline:
  - trade-service -> trade-processor -> position-service

## Metrics Contract Additions

Prometheus metric names required for order observability:

- `traderx_orders_open_total` (gauge)
- `traderx_orders_unfilled_total` (gauge)
- `traderx_orders_pending_by_side{side="Buy|Sell"}` (gauge)
- `traderx_order_events_total{event="create|partial_fill|fill|cancel|reject|force_fill"}` (counter)
- `traderx_order_match_latency_seconds_bucket` / `_sum` / `_count` (histogram)
- `traderx_order_book_age_seconds_bucket` / `_sum` / `_count` (histogram)

## Compatibility Notes

- Existing trade/position/pricing APIs remain backward-compatible from `008`.
- Order-management APIs are additive.
- UI market-trade flow remains available; order-ticket + account-orders tab is introduced as an additional path.
