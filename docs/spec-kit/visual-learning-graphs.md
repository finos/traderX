---
title: Visual Learning Paths
---

# Visual Learning Paths

This is the canonical state progression model for TraderX.

## Official Current Path

```mermaid
flowchart LR
  S001["001: Base Uncontainerized App"] --> S002["002: Edge Proxy Uncontainerized"]
  S002 --> S003["003: Containerized Compose Runtime (NGINX Ingress)"]
  S003 --> S004["004: Kubernetes Runtime"]
  S004 --> S005["005: Radius Platform on Kubernetes"]
  S004 --> S006["006: Tilt Local Dev on Kubernetes"]

  click S001 href "/specs/baseline-uncontainerized-parity" "Open State 001 Spec Pack"
  click S002 href "/specs/edge-proxy-uncontainerized" "Open State 002 Spec Pack"
  click S003 href "/specs/containerized-compose-runtime" "Open State 003 Spec Pack"
  click S004 href "/specs/kubernetes-runtime" "Open State 004 Spec Pack"
  click S005 href "/specs/radius-kubernetes-platform" "Open State 005 Spec Pack"
  click S006 href "/specs/tilt-kubernetes-dev-loop" "Open State 006 Spec Pack"
```

## State To Artifact Mapping

| State | Spec Pack | Architecture | Flows / Runtime Topology | Generated Code Branch |
| --- | --- | --- | --- | --- |
| [`001-baseline-uncontainerized-parity`](/specs/baseline-uncontainerized-parity) | [`specs/001-baseline-uncontainerized-parity`](/specs/baseline-uncontainerized-parity) | [`system/architecture`](/specs/baseline-uncontainerized-parity/system/architecture) | [`system/end-to-end-flows`](/specs/baseline-uncontainerized-parity/system/end-to-end-flows) | `codex/generated-state-001-baseline-uncontainerized-parity` |
| [`002-edge-proxy-uncontainerized`](/specs/edge-proxy-uncontainerized) | [`specs/002-edge-proxy-uncontainerized`](/specs/edge-proxy-uncontainerized) | [`system/architecture`](/specs/edge-proxy-uncontainerized/system/architecture) | [`system/runtime-topology`](/specs/edge-proxy-uncontainerized/system/runtime-topology) | `codex/generated-state-002-edge-proxy-uncontainerized` |
| [`003-containerized-compose-runtime`](/specs/containerized-compose-runtime) | [`specs/003-containerized-compose-runtime`](/specs/containerized-compose-runtime) | [`system/architecture`](/specs/containerized-compose-runtime/system/architecture) | [`system/runtime-topology`](/specs/containerized-compose-runtime/system/runtime-topology) | `codex/generated-state-003-containerized-compose-runtime` |
| [`004-kubernetes-runtime`](/specs/kubernetes-runtime) | [`specs/004-kubernetes-runtime`](/specs/kubernetes-runtime) | [`system/architecture`](/specs/kubernetes-runtime/system/architecture) | [`system/runtime-topology`](/specs/kubernetes-runtime/system/runtime-topology) | `codex/generated-state-004-kubernetes-runtime` |
| [`005-radius-kubernetes-platform`](/specs/radius-kubernetes-platform) | [`specs/005-radius-kubernetes-platform`](/specs/radius-kubernetes-platform) | [`system/architecture`](/specs/radius-kubernetes-platform/system/architecture) | [`system/runtime-topology`](/specs/radius-kubernetes-platform/system/runtime-topology) | `codex/generated-state-005-radius-kubernetes-platform` |
| [`006-tilt-kubernetes-dev-loop`](/specs/tilt-kubernetes-dev-loop) | [`specs/006-tilt-kubernetes-dev-loop`](/specs/tilt-kubernetes-dev-loop) | [`system/architecture`](/specs/tilt-kubernetes-dev-loop/system/architecture) | [`system/runtime-topology`](/specs/tilt-kubernetes-dev-loop/system/runtime-topology) | `codex/generated-state-006-tilt-kubernetes-dev-loop` |

## Learning-Path Families (Planned Beyond `004`)

```mermaid
flowchart LR
  S003["003 Compose Runtime"] --> D["DevEx Track"]
  S003 --> N["Non-Functional Track"]
  S003 --> F["Functional Track"]
  S003 --> A["Architecture Track"]

  D --> D1["DevEx: Kubernetes / GitOps / Platform Ops"]
  N --> N1["NFR: Auth / Observability / Resilience / Data"]
  F --> F1["FR: Domain + UI feature expansion"]
  A --> A1["Architecture: CALM model adoption + generation"]
```

Use `catalog/state-catalog.json` as the canonical state lineage record, and publish code snapshots with:

```bash
bash pipeline/publish-generated-state-branch.sh <state-id> --push
```
