# Feature Specification: Observability with LGTM on Compose

**Feature Branch**: `007-observability-lgtm-compose`  
**Created**: 2026-04-05  
**Status**: Implemented  
**Input**: Transition delta from `006-messaging-nats-replacement`

## User Stories

- As a developer, I want to run TraderX plus observability locally and inspect system behavior without changing app code paths.
- As a maintainer, I want dashboards, logs, and probes provisioned automatically so every generated runtime has the same observability baseline.
- As a platform engineer, I want this to remain a non-functional state with no API/contract drift from state `005`.

## Functional Requirements

- FR-01101: End-to-end functional behavior from state `005` (trade submit, processing, realtime updates, blotters) remains unchanged.
- FR-01102: No new business API endpoints are introduced by this state.

## Non-Functional Requirements

- NFR-01101: Compose runtime includes Grafana, Prometheus, Loki, Tempo, Promtail, OpenTelemetry Collector, and Blackbox Exporter.
- NFR-01102: Grafana starts with pre-provisioned datasources and dashboards from checked-in files.
- NFR-01103: Prometheus continuously probes key TraderX endpoints and exposes availability/latency metrics.
- NFR-01104: Container logs are collected into Loki and queryable from Grafana.
- NFR-01105: Observability stack availability endpoints are healthy before state startup is considered complete.
- NFR-01106: Every service in this state that exposes Prometheus-compatible metrics MUST be scraped by Prometheus and represented in at least one provisioned Grafana dashboard.
- NFR-01107: Smoke tests MUST validate non-empty Loki-backed dashboard content (runtime and service-filtered log queries), not only dashboard provisioning.

## Success Criteria

- SC-01101: `./scripts/start-state-007-observability-lgtm-compose-generated.sh` brings up app + observability stack successfully.
- SC-01102: `./scripts/test-state-007-observability-lgtm-compose.sh` validates observability endpoints, dashboard provisioning, and baseline functional flow.
- SC-01104: Smoke checks fail if Grafana dashboards are present but Loki-backed panels have no ingesting log content.
- SC-01103: `http://localhost:3001` shows provisioned TraderX dashboard(s) and connected datasources.
