# Quickstart: Order Management and Matcher

## 1) Generate This State

```bash
bash pipeline/generate-state.sh 013-order-management-matcher
```

## 2) Start Runtime

```bash
./scripts/start-state-013-order-management-matcher-generated.sh
```

## 3) Run Smoke Tests

```bash
./scripts/test-state-013-order-management-matcher.sh
```

## 4) Stop Runtime

```bash
./scripts/stop-state-013-order-management-matcher-generated.sh
```

## 5) Inspect Order Observability

```bash
ORDER_MATCHER_PORT="${ORDER_MATCHER_PORT:-18110}"

# open/unfilled order gauges
curl -s "http://localhost:${ORDER_MATCHER_PORT}/metrics" | rg "traderx_orders_open_total|traderx_orders_unfilled_total"

# order matcher health
curl -s "http://localhost:${ORDER_MATCHER_PORT}/health"

# dashboard landing
open http://localhost:3000
```
