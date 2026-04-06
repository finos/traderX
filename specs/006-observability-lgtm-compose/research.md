# Research: Observability with LGTM on Compose

## Objective

Add a practical local observability layer to the containerized baseline so developers can inspect availability, latency, logs, and trace plumbing without changing business APIs.

## Inputs Reviewed

- `spec.md`
- `plan.md`
- `tasks.md`
- `system/architecture.md`
- `system/runtime-topology.md`
- `scripts/test-state-003-containerized.sh`

## Key Decisions

1. Build observability on top of state `005` to keep messaging architecture stable while adding ops visibility.
2. Use LGTM stack components with OTel Collector and blackbox probes for broad coverage.
3. Provision Grafana datasources and dashboards from source-controlled files.

## Tradeoffs

- Promtail + Docker discovery is simple for local dev, but not a production log pipeline recommendation.
- OTel Collector is present and ready, but full service-level tracing instrumentation is deferred to future states.

## Risks and Mitigations

- Risk: behavior drift from predecessor state.
  - Mitigation: state smoke tests and conformance checks.
- Risk: unclear ownership of implementation deltas.
  - Mitigation: document deltas in requirements/contracts/system artifacts before code generation.
