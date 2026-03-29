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
  S003 --> P004["004+: Planned Learning-Path States"]
```

## State To Artifact Mapping

| State | Spec Pack | Generated Code Branch |
| --- | --- | --- |
| `001-baseline-uncontainerized-parity` | `specs/001-baseline-uncontainerized-parity` | `codex/generated-state-001-baseline-uncontainerized-parity` |
| `002-edge-proxy-uncontainerized` | `specs/002-edge-proxy-uncontainerized` | `codex/generated-state-002-edge-proxy-uncontainerized` |
| `003-containerized-compose-runtime` | `specs/003-containerized-compose-runtime` | `codex/generated-state-003-containerized-compose-runtime` |

## Learning-Path Families (Planned Beyond `003`)

```mermaid
flowchart LR
  S003["003 Compose Runtime"] --> D["DevEx Track"]
  S003 --> N["Non-Functional Track"]
  S003 --> F["Functional Track"]

  D --> D1["DevEx: Kubernetes / GitOps / Platform Ops"]
  N --> N1["NFR: Auth / Observability / Resilience / Data"]
  F --> F1["FR: Domain + UI feature expansion"]
```

Use `catalog/state-catalog.json` as the canonical state lineage record, and publish code snapshots with:

```bash
bash pipeline/publish-generated-state-branch.sh <state-id> --push
```
