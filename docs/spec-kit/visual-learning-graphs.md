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
  S003 --> S004["004: Kubernetes Runtime (Planned)"]
  S004 --> P005["005+: Planned Learning-Path States"]
```

## State To Artifact Mapping

| State | Spec Pack | Generated Code Branch |
| --- | --- | --- |
| `001-baseline-uncontainerized-parity` | `specs/001-baseline-uncontainerized-parity` | `codex/generated-state-001-baseline-uncontainerized-parity` |
| `002-edge-proxy-uncontainerized` | `specs/002-edge-proxy-uncontainerized` | `codex/generated-state-002-edge-proxy-uncontainerized` |
| `003-containerized-compose-runtime` | `specs/003-containerized-compose-runtime` | `codex/generated-state-003-containerized-compose-runtime` |
| `004-kubernetes-runtime` | `specs/004-kubernetes-runtime` | `codex/generated-state-004-kubernetes-runtime` |

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
