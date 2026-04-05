---
title: ADR-007 Adopt LGTM + OpenTelemetry Stack for States 011 and 012
slug: /adr/007-states-011-012-adopt-lgtm-observability-stack
status: accepted
date: 2026-04-05
decision-makers: Dov Katz, TraderX maintainers
consulted: Core contributors
informed: TraderX users and contributors
---

# Adopt LGTM + OpenTelemetry Stack for States 011 and 012

## Context and Problem Statement

Before state `011`, TraderX had no consistent, end-to-end observability baseline in generated runtime states. We needed a repeatable, local-first observability platform that works across all services and can be layered onto multiple state branches without changing functional behavior.

State `011-observability-lgtm-compose` introduces this as a non-functional track off `003-containerized-compose-runtime`. State `012-observability-on-pricing` applies the same observability decision to the pricing branch (`010-pricing-awareness-market-data`) so architectural and functional tracks stay comparable.

State scope: this ADR applies specifically to states `011` and `012` and descendants that inherit their observability model.

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

* state `011` and `012` runtimes include Grafana, Loki, Tempo, Prometheus, OTel Collector, Promtail, and Blackbox Exporter,
* observability endpoints are healthy in smoke checks (`/api/health`, `/-/ready`, `/ready`, collector health),
* provisioned dashboards are available by default, including TraderX service/runtime views,
* state `011` and `012` do not introduce functional behavior changes relative to their parent states.

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

* State pack: `/specs/011-observability-lgtm-compose`
* State pack: `/specs/012-observability-on-pricing`
* Learning guide: `/docs/learning/state-011-observability-lgtm-compose`
* Learning guide: `/docs/learning/state-012-observability-on-pricing`
* Generated code branch: `code/generated-state-011-observability-lgtm-compose`
* Generated code branch: `code/generated-state-012-observability-on-pricing`
