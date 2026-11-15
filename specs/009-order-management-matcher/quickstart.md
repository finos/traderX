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
# Static contract checks (source assertions and illustrative simulations)
python3 tests/seam-tests/run_all.py

# Execute the real Java matcher and PostgreSQL fresh-install/upgrade tests.
# Requires Java 21 and Docker; starts/removes an isolated database automatically.
bash scripts/test-order-matcher-regression.sh

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

## Existing PostgreSQL volumes

The matcher runs `db/orderbook-market-upgrade.sql` through Spring SQL initialization
before Hibernate examines the schema. It backfills existing orders as `LIMIT`,
sets the type default and constraints, and permits null limit prices. The upgrade
runs atomically and is safe to repeat on restart; existing orders and volumes are
preserved. Initialization errors stop startup rather than leaving a partially
migrated matcher running. Do not delete the database volume to apply this change.

The regression runner tests both the generated fresh schema and a populated
pre-MARKET schema, including a second startup, preservation of the existing order,
and creation of a market order after migration. It also tests the actual Java
service with a mocked trade HTTP boundary. The Python seam checks alone do not
provide behavioral regression coverage.

For a dedicated existing **test** PostgreSQL server, set
`TRADERX_TEST_POSTGRES_URL` (JDBC URL), `TRADERX_TEST_POSTGRES_USER`, and
`TRADERX_TEST_POSTGRES_PASSWORD`. The runner creates/removes uniquely named schemas
and needs permission to do so. Pass a generated target root as the first argument,
or set `TRADERX_GENERATED_ROOT`, when using isolated generation.

## Reuse the state-owned regression contract

`bash scripts/test-order-matcher-regression.sh` also executes the portable HTTP
conformance pack against the real generated matcher JAR. Its assertions are owned
by state 009 (NFR-01322/01323), not by any particular descendant state.

Corporate or overlay implementations can reuse those assertions with their own
lifecycle/observation adapter, even when the implementation was not copied from
TraderX. See [the adapter protocol](tests/conformance/README.md). Generated
snapshots carry the pack and NFRs under `conformance/state-009/`; run it against
the final adapted runtime before publishing that adaptation.
