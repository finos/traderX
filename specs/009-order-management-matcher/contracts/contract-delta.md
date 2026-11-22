# Contract Delta: 009-order-management-matcher

Parent state: `008-pricing-awareness-market-data`

Document any API/event/schema changes for this state.

## OpenAPI Changes

- Add order-management endpoints (exact path naming finalized in implementation):
  - `POST /orders` (create order; accepts `accountId`, `security`, `side`, `quantity`, optional `orderType` [`LIMIT`, `MARKET`] defaulting to `LIMIT`, and `limitPrice` which is required for `LIMIT` and nullable/optional for `MARKET`)
  - `GET /orders` (query/filter orders)
  - `GET /orders/{orderId}` (order details)
  - `POST /orders/{orderId}/cancel` (cancel order; valid for `NEW` and `PARTIALLY_FILLED` statuses)
  - `POST /orders/{orderId}/force-fill` (admin action; valid for `NEW` and `PARTIALLY_FILLED` non-MARKET orders)
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

## Retained database upgrade

Before exposing order operations, atomically backfill missing order types to LIMIT, set the LIMIT default and NOT NULL/allowed-value constraints, and drop LimitPrice NOT NULL. Preserve order IDs, quantities, statuses, prices, and timestamps. Apply safely on subsequent starts and fail startup on migration errors.

## State-owned conformance for adapted implementations

The durable-order/force-fill contract is inherited independently of implementation provenance (NFR-01322/01323). `tests/conformance/run.py` drives the order HTTP API and observes real trade submissions through an adapter-owned probe. See `tests/conformance/README.md` for the versioned protocol. Corporate adapters may change storage, migration tooling, language, and deployment topology while retaining this behavior. Do not duplicate the reference implementation merely to satisfy a structural check.
