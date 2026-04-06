---
title: "April 6, 2026: State 006 - Observability Baseline with LGTM"
slug: /blog/2026-04-06-state-006-observability-baseline
---

# State 006: Observability Baseline with LGTM

State `006-observability-lgtm-compose` adds a reusable observability baseline on top of the architecture chain (`004` PostgreSQL + `005` NATS).

The goal was to make diagnostics first-class without changing business behavior. We wanted consistent local visibility across logs, metrics, traces, and service health for every generated runtime that inherits this state.

## What Was Added

- LGTM stack in compose runtime: Grafana, Loki, Tempo, Prometheus.
- OpenTelemetry collector wiring for cross-service telemetry flow.
- Baseline probes and health checks for observability services.
- Default dashboards and smoke checks so observability is verifiable, not aspirational.

## Why This Matters

- Functional states can now be developed with immediate telemetry feedback.
- Regressions are easier to detect and isolate across services.
- Later states (`007`, `008`, and convergence states) inherit the same baseline by default.

## Decision Record

The state-scoped rationale is captured in:

- [ADR-007 Adopt LGTM + OpenTelemetry Stack for State 006 Baseline](/docs/adr/007-state-006-adopt-lgtm-observability-stack)

## Spec + Code Links

- State spec pack: [/specs/observability-lgtm-compose](/specs/observability-lgtm-compose)
- Learning guide: [/docs/learning/state-006-observability-lgtm-compose](/docs/learning/state-006-observability-lgtm-compose)
- Generated code branch: [code/generated-state-006-observability-lgtm-compose](https://github.com/finos/traderX/tree/code/generated-state-006-observability-lgtm-compose)
- Compare vs parent (`005`): [code/generated-state-005-messaging-nats-replacement...code/generated-state-006-observability-lgtm-compose](https://github.com/finos/traderX/compare/code%2Fgenerated-state-005-messaging-nats-replacement...code%2Fgenerated-state-006-observability-lgtm-compose)
