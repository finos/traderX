# Feature Specification: Observability with LGTM on Pricing State

**Feature Branch**: `008-pricing-awareness-market-data`  
**Created**: 2026-04-05  
**Status**: Implemented  
**Input**: Transition delta from `008-pricing-awareness-market-data`

## User Stories

- As a developer, I want pricing-enabled TraderX (`010`) to include observability without losing realtime behavior.
- As a maintainer, I want pricing and messaging runtime health visible in Grafana out of the box.
- As a platform engineer, I want this state to remain non-functional, with no FR/API drift from state `010`.

## Functional Requirements

- FR-01201: Pricing, trade, position, and realtime behavior from state `010` remains unchanged.
- FR-01202: No new business API endpoints are introduced by this state.

## Non-Functional Requirements

- NFR-01201: Compose runtime includes Grafana, Prometheus, Loki, Tempo, Promtail, OpenTelemetry Collector, and Blackbox Exporter.
- NFR-01202: Prometheus probes include pricing-sensitive endpoints (`price-publisher` and NATS monitor).
- NFR-01203: Grafana includes pricing/observability dashboards focused on health, latency, and logs for pricing/trade pipeline services.
- NFR-01204: Observability stack availability endpoints are healthy before state startup is considered complete.

## Success Criteria

- SC-01201: `./scripts/start-state-008-pricing-awareness-market-data-generated.sh` starts app + observability stack successfully.
- SC-01202: `./scripts/test-state-008-pricing-awareness-market-data.sh` validates observability endpoints, probe targets, and inherited pricing behavior.
- SC-01203: Grafana dashboards are provisioned and available for pricing-aware runtime inspection.
