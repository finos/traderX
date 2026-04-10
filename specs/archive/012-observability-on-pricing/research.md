# Research: Observability with LGTM on Pricing State

## Objective

Carry the LGTM observability stack onto the pricing-aware runtime and expose pricing-path health in dashboards and probes.

## Inputs Reviewed

- `spec.md`
- `plan.md`
- `tasks.md`
- `system/architecture.md`
- `system/runtime-topology.md`
- `scripts/test-state-008-pricing-awareness-market-data.sh`

## Key Decisions

1. Build from state `010` to preserve pricing and NATS messaging behavior.
2. Add pricing-specific probe targets and dashboards (price publisher, NATS monitor, trade/pricing logs).
3. Keep APIs and business behaviors unchanged.

## Tradeoffs

- OTel Collector and Tempo are wired for traces, but full service-level instrumentation remains a future enhancement.
- Local-dev credentials and defaults are intentionally simple for learning ergonomics.

## Risks and Mitigations

- Risk: behavior drift from predecessor state.
  - Mitigation: state smoke tests and conformance checks.
- Risk: unclear ownership of implementation deltas.
  - Mitigation: document deltas in requirements/contracts/system artifacts before code generation.
