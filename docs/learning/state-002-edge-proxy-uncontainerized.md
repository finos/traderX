---
title: "State 002: Edge Proxy Uncontainerized"
---

# State 002 Learning Guide

## Purpose

Keeps uncontainerized runtime but introduces a single browser-facing edge proxy.

## Run

```bash
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./scripts/start-state-002-edge-proxy-generated.sh
```

Browser entrypoint: `http://localhost:18080`

## What Changed From 001

- Added `edge-proxy/` component.
- Browser traffic consolidates through one origin.
- Functional behavior remains baseline-compatible.

## Canonical Spec Links

- State spec pack: [/specs/edge-proxy-uncontainerized](/specs/edge-proxy-uncontainerized)
- Architecture: [/specs/edge-proxy-uncontainerized/system/architecture](/specs/edge-proxy-uncontainerized/system/architecture)
- Runtime topology: [/specs/edge-proxy-uncontainerized/system/runtime-topology](/specs/edge-proxy-uncontainerized/system/runtime-topology)

## Generated Code Snapshot

- [code/generated-state-002-edge-proxy-uncontainerized](https://github.com/finos/traderX/tree/code/generated-state-002-edge-proxy-uncontainerized)

## Lineage

- Previous: `001-baseline-uncontainerized-parity`
- Next: `003-containerized-compose-runtime`
