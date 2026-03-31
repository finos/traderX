---
title: "State 006: Tilt Dev Loop on Kubernetes"
---

# State 006 Learning Guide

## Purpose

Adds Tilt-driven local developer loop assets on top of Kubernetes runtime.

## Run

```bash
./scripts/start-state-006-tilt-kubernetes-dev-loop-generated.sh --provider kind
```

Runtime entrypoint remains: `http://localhost:8080`

## What Changed From 004

- Added Tilt assets (`Tiltfile`, settings, loop docs).
- Focused on faster local iteration while preserving behavior.

## Canonical Spec Links

- State spec pack: [/specs/tilt-kubernetes-dev-loop](/specs/tilt-kubernetes-dev-loop)
- Architecture: [/specs/tilt-kubernetes-dev-loop/system/architecture](/specs/tilt-kubernetes-dev-loop/system/architecture)
- Runtime topology: [/specs/tilt-kubernetes-dev-loop/system/runtime-topology](/specs/tilt-kubernetes-dev-loop/system/runtime-topology)

## Generated Code Snapshot

- [code/generated-state-006-tilt-kubernetes-dev-loop](https://github.com/finos/traderX/tree/code/generated-state-006-tilt-kubernetes-dev-loop)

## Lineage

- Previous: `004-kubernetes-runtime`
- Next: planned
