---
title: ADR-007 Adopt LGTM + OpenTelemetry Stack for State 006 Baseline
slug: /adr/007-state-006-adopt-lgtm-observability-stack
status: accepted
date: 2026-04-05
decision-makers: Dov Katz, TraderX maintainers
consulted: Core contributors
informed: TraderX users and contributors
---

# Adopt LGTM + OpenTelemetry Stack from State 006 Onward

## Context and Problem Statement

Before state `006`, TraderX had no consistent, end-to-end observability baseline in generated runtime states. We needed a repeatable, local-first observability platform that works across all services and can be layered onto multiple state branches without changing functional behavior.

State `006-observability-lgtm-compose` introduces this baseline on the canonical architecture path. Descendant states (including `007`, `008`, and convergence states) inherit the same observability decision unless explicitly changed.

State scope: this ADR applies specifically to state `006` and descendants that inherit its observability model.

## Decision Drivers

* Keep observability open-source and runnable locally in Docker Compose.
* Provide logs, metrics, traces, and health probing in one baseline.
* Keep functional flows unchanged while improving operational visibility.
* Support pre-provisioned dashboards for immediate value to users.
* Keep generated-state behavior deterministic and testable in CI.

## Considered Options

* Minimal logging-only stack (for example Loki + Promtail + Grafana).
* Metrics-only stack (Prometheus + Grafana).
* Full LGTM + OpenTelemetry stack in Compose:
  * Grafana
  * Loki
  * Tempo
  * Prometheus
  * OpenTelemetry Collector
  * Promtail
  * Blackbox Exporter

## Decision Outcome

Chosen option: "Full LGTM + OpenTelemetry stack in Compose", because it provides complete, local-first observability coverage while preserving state behavior and allowing consistent instrumentation across future branches.

### Consequences

* Good, because users get operational visibility without extra infrastructure.
* Good, because the same observability baseline can be reused across state branches.
* Good, because dashboards, probes, and scrape targets can be tested and versioned in specs.
* Bad, because runtime complexity and startup time increase versus app-only states.
* Bad, because dashboard/provisioning drift must be managed carefully in generated artifacts.

### Confirmation

Decision compliance is confirmed when:

* state `006` runtime includes Grafana, Loki, Tempo, Prometheus, OTel Collector, Promtail, and Blackbox Exporter,
* observability endpoints are healthy in smoke checks (`/api/health`, `/-/ready`, `/ready`, collector health),
* provisioned dashboards are available by default, including TraderX service/runtime views,
* descendant states that keep this stack continue to expose healthy observability endpoints.

## Pros and Cons of the Options

### Minimal logging-only stack

* Good, because setup is smaller and faster.
* Bad, because metrics and traces are missing.
* Bad, because non-functional comparisons across states are weaker.

### Metrics-only stack

* Good, because it covers service health and basic SLO signals.
* Bad, because root-cause analysis is limited without centralized logs/traces.
* Bad, because operational demonstrations are incomplete.

### Full LGTM + OpenTelemetry stack

* Good, because logs/metrics/traces/probes are all available.
* Good, because Grafana can present a unified operational view.
* Good, because this becomes a reusable observability baseline for future states.
* Bad, because it adds operational overhead for local runs.

## More Information

Related states and artifacts:

* State pack: `/specs/006-observability-lgtm-compose`
* Learning guide: `/docs/learning/state-006-observability-lgtm-compose`
* Generated code branch: `code/generated-state-006-observability-lgtm-compose`
