---
title: "State 001: Base Uncontainerized"
---

# State 001 Learning Guide

## Purpose

This is the intentionally simple baseline: local processes, fixed ports, explicit cross-origin calls.

## Run

```bash
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./scripts/start-base-uncontainerized-generated.sh
```

UI: `http://localhost:18093`

## Code Areas To Read

- `account-service/`, `trade-service/`, `position-service/`
- `people-service/` (.NET)
- `reference-data/`, `trade-feed/` (Node/Nest)
- `database/` (H2 process bootstrap)
- `web-front-end/angular/`

## Canonical Spec Links

- State spec pack: [/specs/baseline-uncontainerized-parity](/specs/baseline-uncontainerized-parity)
- Architecture: [/specs/baseline-uncontainerized-parity/system/architecture](/specs/baseline-uncontainerized-parity/system/architecture)
- End-to-end flows: [/specs/baseline-uncontainerized-parity/system/end-to-end-flows](/specs/baseline-uncontainerized-parity/system/end-to-end-flows)

## Generated Code Snapshot

- [code/generated-state-001-baseline-uncontainerized-parity](https://github.com/finos/traderX/tree/code/generated-state-001-baseline-uncontainerized-parity)

## Lineage

- Previous: none
- Next: `002-edge-proxy-uncontainerized`
