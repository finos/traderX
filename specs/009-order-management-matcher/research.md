# Research: Order Management and Matcher

## Objective

Define a functional state on top of `008` that introduces order matching while preserving pricing behavior and extending observability to order operations.

## Inputs Reviewed

- `spec.md`
- `plan.md`
- `tasks.md`
- `system/architecture.md`
- `system/runtime-topology.md`
- state `007` observability stack and dashboard/probe patterns

## Key Decisions

1. Build on top of state `008` while preserving observability patterns from state `007`.
2. Treat order management as additive to existing trade workflows; do not break current trade ticket path.
3. Expose order metrics directly from matcher/API path for precise visibility instead of blackbox-only inference.
4. Standardize required metric names in contract artifacts so generated implementations remain comparable.
5. Keep generation and runtime steps deterministic and scriptable.
6. Implement matcher as Spring Boot (not Python) for operational consistency with existing JVM services.
7. Persist order state in shared DB so active orders survive order-matcher restart and recover without re-seeding.

## Risks and Mitigations

- Risk: behavior drift from predecessor state.
  - Mitigation: state smoke tests and conformance checks.
- Risk: order lifecycle regressions (open order count incorrect, stale statuses).
  - Mitigation: enforce metric contracts (`traderx_orders_open_total`, `traderx_orders_unfilled_total`) in smoke checks.
- Risk: observability noise without actionable dashboards.
  - Mitigation: require focused order dashboards (queue depth, lifecycle rates, latency, failures).
