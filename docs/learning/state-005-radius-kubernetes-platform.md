---
title: "State 005: Radius on Kubernetes"
---

# State 005 Learning Guide

## Purpose

Adds Radius platform modeling artifacts on top of the Kubernetes runtime baseline.

## Run

```bash
./scripts/start-state-005-radius-kubernetes-platform-generated.sh --provider kind
```

Runtime entrypoint remains: `http://localhost:8080`

## What Changed From 004

- Added Radius resource model and app definition artifacts.
- Kept Kubernetes runtime behavior and baseline functional contracts.

## Canonical Spec Links

- State spec pack: [/specs/radius-kubernetes-platform](/specs/radius-kubernetes-platform)
- Architecture: [/specs/radius-kubernetes-platform/system/architecture](/specs/radius-kubernetes-platform/system/architecture)
- Runtime topology: [/specs/radius-kubernetes-platform/system/runtime-topology](/specs/radius-kubernetes-platform/system/runtime-topology)

## Generated Code Snapshot

- [code/generated-state-005-radius-kubernetes-platform](https://github.com/finos/traderX/tree/code/generated-state-005-radius-kubernetes-platform)

## Lineage

- Previous: `004-kubernetes-runtime`
- Next: planned
