# Quickstart: Order Management and Matcher

## 1) Generate This State

```bash
bash pipeline/generate-state.sh 009-order-management-matcher
```

## 2) Start Runtime

```bash
./scripts/start-state-009-order-management-matcher-generated.sh
./scripts/start-state-009-order-management-matcher-generated.sh --skip-build
```

## 3) Run Smoke Tests

```bash
./scripts/test-state-009-order-management-matcher.sh
./scripts/test-state-009-order-management-matcher.sh --skip-messaging
./scripts/test-messaging-009-order-management-matcher.sh
```

## 4) Stop Runtime

```bash
./scripts/stop-state-009-order-management-matcher-generated.sh
```

## 5) Inspect Order Observability

```bash
ORDER_MATCHER_PORT="${ORDER_MATCHER_PORT:-18110}"

# open/unfilled order gauges
curl -s "http://localhost:${ORDER_MATCHER_PORT}/metrics" | rg "traderx_orders_open_total|traderx_orders_unfilled_total"

# order matcher health
curl -s "http://localhost:${ORDER_MATCHER_PORT}/health"

# anonymous dashboard landing through ingress
open http://localhost:8080/grafana/

# local admin login, using credentials printed by the start script
open http://localhost:3001
```
