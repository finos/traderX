# Research: Pricing Awareness and Market Data Streaming

## Objective

Define the transition from state `007` to `010` by introducing pricing-aware trading and position valuation behavior.

## Inputs Reviewed

- `spec.md`
- `plan.md`
- `tasks.md`
- `requirements/functional-delta.md`
- `requirements/nonfunctional-delta.md`
- `system/architecture.md`
- `system/runtime-topology.md`

## Key Decisions

1. Add market price awareness to trade and position views.
2. Keep real-time updates aligned with NATS messaging behavior from state `007`.
3. Preserve baseline user flows while extending functional capabilities for valuation and P&L.
