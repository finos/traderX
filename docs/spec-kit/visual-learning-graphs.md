---
title: Visual Learning Paths
---

# Visual Learning Paths

This is the canonical state progression model for TraderX.

## Official Current Graph

```mermaid
flowchart LR
  S001["001: Base Uncontainerized App"] --> S002["002: Edge Proxy Uncontainerized"]
  S002 --> S003["003: Containerized Compose Runtime (NGINX Ingress)"]
  S003 --> S004["004: Kubernetes Runtime (DevEx)"]
  S003 --> S007["007: Messaging NATS Replacement (Architecture)"]
  S003 --> S009["009: PostgreSQL Replacement (Architecture)"]
  S007 --> S010["010: Pricing Awareness + Market Data (Functional)"]
  S004 --> S005["005: Radius Platform on Kubernetes"]
  S004 --> S006["006: Tilt Local Dev on Kubernetes"]
  S007 -.-> S008["008: Kubernetes + NATS (Planned)"]

  click S001 href "/specs/baseline-uncontainerized-parity" "Open State 001 Spec Pack"
  click S002 href "/specs/edge-proxy-uncontainerized" "Open State 002 Spec Pack"
  click S003 href "/specs/containerized-compose-runtime" "Open State 003 Spec Pack"
  click S004 href "/specs/kubernetes-runtime" "Open State 004 Spec Pack"
  click S005 href "/specs/radius-kubernetes-platform" "Open State 005 Spec Pack"
  click S006 href "/specs/tilt-kubernetes-dev-loop" "Open State 006 Spec Pack"
  click S007 href "/specs/messaging-nats-replacement" "Open State 007 Spec Pack"
  click S009 href "/specs/postgres-database-replacement" "Open State 009 Spec Pack"
  click S010 href "/specs/pricing-awareness-market-data" "Open State 010 Spec Pack"
```

## State To Artifact Mapping

| State | Spec Pack | Architecture | Flows / Runtime Topology | Generated Code Branch |
| --- | --- | --- | --- | --- |
| [`001-baseline-uncontainerized-parity`](/specs/baseline-uncontainerized-parity) | [`specs/001-baseline-uncontainerized-parity`](/specs/baseline-uncontainerized-parity) | [`system/architecture`](/specs/baseline-uncontainerized-parity/system/architecture) | [`system/end-to-end-flows`](/specs/baseline-uncontainerized-parity/system/end-to-end-flows) | `code/generated-state-001-baseline-uncontainerized-parity` |
| [`002-edge-proxy-uncontainerized`](/specs/edge-proxy-uncontainerized) | [`specs/002-edge-proxy-uncontainerized`](/specs/edge-proxy-uncontainerized) | [`system/architecture`](/specs/edge-proxy-uncontainerized/system/architecture) | [`system/runtime-topology`](/specs/edge-proxy-uncontainerized/system/runtime-topology) | `code/generated-state-002-edge-proxy-uncontainerized` |
| [`003-containerized-compose-runtime`](/specs/containerized-compose-runtime) | [`specs/003-containerized-compose-runtime`](/specs/containerized-compose-runtime) | [`system/architecture`](/specs/containerized-compose-runtime/system/architecture) | [`system/runtime-topology`](/specs/containerized-compose-runtime/system/runtime-topology) | `code/generated-state-003-containerized-compose-runtime` |
| [`004-kubernetes-runtime`](/specs/kubernetes-runtime) | [`specs/004-kubernetes-runtime`](/specs/kubernetes-runtime) | [`system/architecture`](/specs/kubernetes-runtime/system/architecture) | [`system/runtime-topology`](/specs/kubernetes-runtime/system/runtime-topology) | `code/generated-state-004-kubernetes-runtime` |
| [`005-radius-kubernetes-platform`](/specs/radius-kubernetes-platform) | [`specs/005-radius-kubernetes-platform`](/specs/radius-kubernetes-platform) | [`system/architecture`](/specs/radius-kubernetes-platform/system/architecture) | [`system/runtime-topology`](/specs/radius-kubernetes-platform/system/runtime-topology) | `code/generated-state-005-radius-kubernetes-platform` |
| [`006-tilt-kubernetes-dev-loop`](/specs/tilt-kubernetes-dev-loop) | [`specs/006-tilt-kubernetes-dev-loop`](/specs/tilt-kubernetes-dev-loop) | [`system/architecture`](/specs/tilt-kubernetes-dev-loop/system/architecture) | [`system/runtime-topology`](/specs/tilt-kubernetes-dev-loop/system/runtime-topology) | `code/generated-state-006-tilt-kubernetes-dev-loop` |
| [`007-messaging-nats-replacement`](/specs/messaging-nats-replacement) | [`specs/007-messaging-nats-replacement`](/specs/messaging-nats-replacement) | [`system/architecture`](/specs/messaging-nats-replacement/system/architecture) | [`system/runtime-topology`](/specs/messaging-nats-replacement/system/runtime-topology) | `code/generated-state-007-messaging-nats-replacement` |
| [`009-postgres-database-replacement`](/specs/postgres-database-replacement) | [`specs/009-postgres-database-replacement`](/specs/postgres-database-replacement) | [`system/architecture`](/specs/postgres-database-replacement/system/architecture) | [`system/runtime-topology`](/specs/postgres-database-replacement/system/runtime-topology) | `code/generated-state-009-postgres-database-replacement` |
| [`010-pricing-awareness-market-data`](/specs/pricing-awareness-market-data) | [`specs/010-pricing-awareness-market-data`](/specs/pricing-awareness-market-data) | [`system/architecture`](/specs/pricing-awareness-market-data/system/architecture) | [`system/runtime-topology`](/specs/pricing-awareness-market-data/system/runtime-topology) | `code/generated-state-010-pricing-awareness-market-data` |

## Swimlane View

```mermaid
flowchart LR
  B["Shared Baseline Lane"] --> S001["001"]
  S001 --> S002["002"]
  S002 --> S003["003"]

  S003 --> D4["004 DevEx: Kubernetes"]
  D4 --> D5["005 DevEx: Radius"]
  D4 --> D6["006 DevEx: Tilt"]

  S003 --> A7["007 Architecture: NATS Messaging"]
  S003 --> A9["009 Architecture: PostgreSQL Database"]
  A7 --> F10["010 Functional: Pricing Awareness + Market Data"]
  A7 -.-> A8["008 Architecture: Kubernetes + NATS (planned)"]

  S003 -.-> N1["Non-Functional lane (planned)"]
  S003 -.-> F1["Functional lane (planned)"]
```

Use `catalog/state-catalog.json` as the canonical state lineage record, and publish code snapshots with:

```bash
bash pipeline/publish-generated-state-branch.sh <state-id> --push
```
