---
title: "State 003: Containerized Compose Runtime"
---

# State 003 Learning Guide

## Purpose

Moves runtime from local host processes to Docker Compose, with NGINX ingress.

## Run

```bash
./scripts/start-state-003-containerized-generated.sh
```

Entrypoint: `http://localhost:8080`

## What Changed From 002

- Added compose packaging and Dockerfiles.
- Added NGINX ingress for UI/API/WebSocket routing.
- Preserved baseline API contracts and workflows.

## Canonical Spec Links

- State spec pack: [/specs/containerized-compose-runtime](/specs/containerized-compose-runtime)
- Architecture: [/specs/containerized-compose-runtime/system/architecture](/specs/containerized-compose-runtime/system/architecture)
- Runtime topology: [/specs/containerized-compose-runtime/system/runtime-topology](/specs/containerized-compose-runtime/system/runtime-topology)

## Generated Code Snapshot

- [code/generated-state-003-containerized-compose-runtime](https://github.com/finos/traderX/tree/code/generated-state-003-containerized-compose-runtime)

## Lineage

- Previous: `002-edge-proxy-uncontainerized`
- Next: `004-kubernetes-runtime`
