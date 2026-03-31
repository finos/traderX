---
title: "State 004: Kubernetes Runtime"
---

# State 004 Learning Guide

## Purpose

Moves runtime orchestration from Compose to Kubernetes (Kind default, Minikube supported).

## Run

```bash
./scripts/start-state-004-kubernetes-generated.sh --provider kind
```

Entrypoint: `http://localhost:8080`

## What Changed From 003

- Added Kubernetes manifests and image build plan.
- Added cluster bootstrap and runtime lifecycle scripts.
- Preserved baseline functional behavior.

## Canonical Spec Links

- State spec pack: [/specs/kubernetes-runtime](/specs/kubernetes-runtime)
- Architecture: [/specs/kubernetes-runtime/system/architecture](/specs/kubernetes-runtime/system/architecture)
- Runtime topology: [/specs/kubernetes-runtime/system/runtime-topology](/specs/kubernetes-runtime/system/runtime-topology)

## Generated Code Snapshot

- [code/generated-state-004-kubernetes-runtime](https://github.com/finos/traderX/tree/code/generated-state-004-kubernetes-runtime)

## Lineage

- Previous: `003-containerized-compose-runtime`
- Next: `005-radius-kubernetes-platform`, `006-tilt-kubernetes-dev-loop`
