---
title: Visual Learning Paths
---

# Visual Learning Paths

This page is generated from `catalog/state-catalog.json`.

## Official Current Graph

```mermaid
flowchart LR
  S001_baseline_uncontainerized_parity["001: Simple App - Base Uncontainerized App"]
  S002_edge_proxy_uncontainerized["002: Edge Proxy Uncontainerized"]
  S003_containerized_compose_runtime["003: Containerized Compose Runtime (NGINX Ingress)"]
  S004_kubernetes_runtime["004: Kubernetes Runtime Baseline"]
  S005_radius_kubernetes_platform["005: Radius Platform on Kubernetes"]
  S006_tilt_kubernetes_dev_loop["006: Tilt Local Dev on Kubernetes"]
  S007_messaging_nats_replacement["007: Messaging Layer Replacement with NATS"]
  S009_postgres_database_replacement["009: PostgreSQL Database Replacement"]
  S010_pricing_awareness_market_data["010: Pricing Awareness and Market Data Streaming"]
  S011_observability_lgtm_compose["011: Observability with LGTM on Compose"]
  S012_observability_on_pricing["012: Observability with LGTM on Pricing State"]
  S001_baseline_uncontainerized_parity --> S002_edge_proxy_uncontainerized
  S002_edge_proxy_uncontainerized --> S003_containerized_compose_runtime
  S003_containerized_compose_runtime --> S004_kubernetes_runtime
  S004_kubernetes_runtime --> S005_radius_kubernetes_platform
  S004_kubernetes_runtime --> S006_tilt_kubernetes_dev_loop
  S003_containerized_compose_runtime --> S007_messaging_nats_replacement
  S003_containerized_compose_runtime --> S009_postgres_database_replacement
  S007_messaging_nats_replacement --> S010_pricing_awareness_market_data
  S003_containerized_compose_runtime --> S011_observability_lgtm_compose
  S010_pricing_awareness_market_data --> S012_observability_on_pricing
  click S001_baseline_uncontainerized_parity href "/specs/baseline-uncontainerized-parity" "Open State 001 Spec Pack"
  click S002_edge_proxy_uncontainerized href "/specs/edge-proxy-uncontainerized" "Open State 002 Spec Pack"
  click S003_containerized_compose_runtime href "/specs/containerized-compose-runtime" "Open State 003 Spec Pack"
  click S004_kubernetes_runtime href "/specs/kubernetes-runtime" "Open State 004 Spec Pack"
  click S005_radius_kubernetes_platform href "/specs/radius-kubernetes-platform" "Open State 005 Spec Pack"
  click S006_tilt_kubernetes_dev_loop href "/specs/tilt-kubernetes-dev-loop" "Open State 006 Spec Pack"
  click S007_messaging_nats_replacement href "/specs/messaging-nats-replacement" "Open State 007 Spec Pack"
  click S009_postgres_database_replacement href "/specs/postgres-database-replacement" "Open State 009 Spec Pack"
  click S010_pricing_awareness_market_data href "/specs/pricing-awareness-market-data" "Open State 010 Spec Pack"
  click S011_observability_lgtm_compose href "/specs/observability-lgtm-compose" "Open State 011 Spec Pack"
  click S012_observability_on_pricing href "/specs/observability-on-pricing" "Open State 012 Spec Pack"
```

## State To Artifact Mapping

| State | Spec Pack | Architecture | Flows / Runtime Topology | Learning Guide | Generated Code Branch |
| --- | --- | --- | --- | --- | --- |
| [`001-baseline-uncontainerized-parity`](/specs/baseline-uncontainerized-parity) | [link](/specs/baseline-uncontainerized-parity) | [link](/specs/baseline-uncontainerized-parity/system/architecture) | [link](/specs/baseline-uncontainerized-parity/system/end-to-end-flows) | [link](/docs/learning/state-001-baseline-uncontainerized-parity) | [code/generated-state-001-baseline-uncontainerized-parity](https://github.com/finos/traderX/tree/code/generated-state-001-baseline-uncontainerized-parity) |
| [`002-edge-proxy-uncontainerized`](/specs/edge-proxy-uncontainerized) | [link](/specs/edge-proxy-uncontainerized) | [link](/specs/edge-proxy-uncontainerized/system/architecture) | [link](/specs/edge-proxy-uncontainerized/system/runtime-topology) | [link](/docs/learning/state-002-edge-proxy-uncontainerized) | [code/generated-state-002-edge-proxy-uncontainerized](https://github.com/finos/traderX/tree/code/generated-state-002-edge-proxy-uncontainerized) |
| [`003-containerized-compose-runtime`](/specs/containerized-compose-runtime) | [link](/specs/containerized-compose-runtime) | [link](/specs/containerized-compose-runtime/system/architecture) | [link](/specs/containerized-compose-runtime/system/runtime-topology) | [link](/docs/learning/state-003-containerized-compose-runtime) | [code/generated-state-003-containerized-compose-runtime](https://github.com/finos/traderX/tree/code/generated-state-003-containerized-compose-runtime) |
| [`004-kubernetes-runtime`](/specs/kubernetes-runtime) | [link](/specs/kubernetes-runtime) | [link](/specs/kubernetes-runtime/system/architecture) | [link](/specs/kubernetes-runtime/system/runtime-topology) | [link](/docs/learning/state-004-kubernetes-runtime) | [code/generated-state-004-kubernetes-runtime](https://github.com/finos/traderX/tree/code/generated-state-004-kubernetes-runtime) |
| [`005-radius-kubernetes-platform`](/specs/radius-kubernetes-platform) | [link](/specs/radius-kubernetes-platform) | [link](/specs/radius-kubernetes-platform/system/architecture) | [link](/specs/radius-kubernetes-platform/system/runtime-topology) | [link](/docs/learning/state-005-radius-kubernetes-platform) | [code/generated-state-005-radius-kubernetes-platform](https://github.com/finos/traderX/tree/code/generated-state-005-radius-kubernetes-platform) |
| [`006-tilt-kubernetes-dev-loop`](/specs/tilt-kubernetes-dev-loop) | [link](/specs/tilt-kubernetes-dev-loop) | [link](/specs/tilt-kubernetes-dev-loop/system/architecture) | [link](/specs/tilt-kubernetes-dev-loop/system/runtime-topology) | [link](/docs/learning/state-006-tilt-kubernetes-dev-loop) | [code/generated-state-006-tilt-kubernetes-dev-loop](https://github.com/finos/traderX/tree/code/generated-state-006-tilt-kubernetes-dev-loop) |
| [`007-messaging-nats-replacement`](/specs/messaging-nats-replacement) | [link](/specs/messaging-nats-replacement) | [link](/specs/messaging-nats-replacement/system/architecture) | [link](/specs/messaging-nats-replacement/system/runtime-topology) | [link](/docs/learning/state-007-messaging-nats-replacement) | [code/generated-state-007-messaging-nats-replacement](https://github.com/finos/traderX/tree/code/generated-state-007-messaging-nats-replacement) |
| [`009-postgres-database-replacement`](/specs/postgres-database-replacement) | [link](/specs/postgres-database-replacement) | [link](/specs/postgres-database-replacement/system/architecture) | [link](/specs/postgres-database-replacement/system/runtime-topology) | [link](/docs/learning/state-009-postgres-database-replacement) | [code/generated-state-009-postgres-database-replacement](https://github.com/finos/traderX/tree/code/generated-state-009-postgres-database-replacement) |
| [`010-pricing-awareness-market-data`](/specs/pricing-awareness-market-data) | [link](/specs/pricing-awareness-market-data) | [link](/specs/pricing-awareness-market-data/system/architecture) | [link](/specs/pricing-awareness-market-data/system/runtime-topology) | [link](/docs/learning/state-010-pricing-awareness-market-data) | [code/generated-state-010-pricing-awareness-market-data](https://github.com/finos/traderX/tree/code/generated-state-010-pricing-awareness-market-data) |
| [`011-observability-lgtm-compose`](/specs/observability-lgtm-compose) | [link](/specs/observability-lgtm-compose) | [link](/specs/observability-lgtm-compose/system/architecture) | [link](/specs/observability-lgtm-compose/system/runtime-topology) | [link](/docs/learning/state-011-observability-lgtm-compose) | [code/generated-state-011-observability-lgtm-compose](https://github.com/finos/traderX/tree/code/generated-state-011-observability-lgtm-compose) |
| [`012-observability-on-pricing`](/specs/observability-on-pricing) | [link](/specs/observability-on-pricing) | [link](/specs/observability-on-pricing/system/architecture) | [link](/specs/observability-on-pricing/system/runtime-topology) | [link](/docs/learning/state-012-observability-on-pricing) | [code/generated-state-012-observability-on-pricing](https://github.com/finos/traderX/tree/code/generated-state-012-observability-on-pricing) |

## Swimlane View

```mermaid
flowchart LR
  subgraph BASELINE["Baseline Track"]
    S001_baseline_uncontainerized_parity["001: Simple App - Base Uncontainerized App"]
    S002_edge_proxy_uncontainerized["002: Edge Proxy Uncontainerized"]
    S003_containerized_compose_runtime["003: Containerized Compose Runtime (NGINX Ingress)"]
  end
  subgraph DEVEX["Devex Track"]
    S004_kubernetes_runtime["004: Kubernetes Runtime Baseline"]
    S005_radius_kubernetes_platform["005: Radius Platform on Kubernetes"]
    S006_tilt_kubernetes_dev_loop["006: Tilt Local Dev on Kubernetes"]
  end
  subgraph ARCHITECTURE["Architecture Track"]
    S007_messaging_nats_replacement["007: Messaging Layer Replacement with NATS"]
    S009_postgres_database_replacement["009: PostgreSQL Database Replacement"]
  end
  subgraph FUNCTIONAL["Functional Track"]
    S010_pricing_awareness_market_data["010: Pricing Awareness and Market Data Streaming"]
  end
  subgraph NONFUNCTIONAL["Nonfunctional Track"]
    S011_observability_lgtm_compose["011: Observability with LGTM on Compose"]
    S012_observability_on_pricing["012: Observability with LGTM on Pricing State"]
  end
  S001_baseline_uncontainerized_parity --> S002_edge_proxy_uncontainerized
  S002_edge_proxy_uncontainerized --> S003_containerized_compose_runtime
  S003_containerized_compose_runtime --> S004_kubernetes_runtime
  S004_kubernetes_runtime --> S005_radius_kubernetes_platform
  S004_kubernetes_runtime --> S006_tilt_kubernetes_dev_loop
  S003_containerized_compose_runtime --> S007_messaging_nats_replacement
  S003_containerized_compose_runtime --> S009_postgres_database_replacement
  S007_messaging_nats_replacement --> S010_pricing_awareness_market_data
  S003_containerized_compose_runtime --> S011_observability_lgtm_compose
  S010_pricing_awareness_market_data --> S012_observability_on_pricing
```

Use `catalog/state-catalog.json` as the canonical state lineage record.
