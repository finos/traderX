---
title: Live Environments
---

# Live Environments

This page tracks canonical live TraderX demo environments and their mapped generated-state branches.

Source of truth:

- `catalog/live-environments.json`
- `catalog/state-catalog.json`

## Current Live Demos

| Environment | URL | State | Generated Branch | Notes |
| --- | --- | --- | --- | --- |
| `demo-004` | [demo.traderx.finos.org](https://demo.traderx.finos.org) | `004-containerized-compose-runtime` | [`code/generated-state-004-containerized-compose-runtime`](https://github.com/finos/traderX/tree/code/generated-state-004-containerized-compose-runtime) | Containerized compose baseline demo |
| `demo-advanced-009` | [demo-advanced.traderx.finos.org](https://demo-advanced.traderx.finos.org) | `009-order-management-matcher` | [`code/generated-state-009-order-management-matcher`](https://github.com/finos/traderX/tree/code/generated-state-009-order-management-matcher) | NATS + order-management demo |

## Update Process

When an environment is moved to a different state:

1. Update `catalog/live-environments.json`.
2. Ensure the target state `deploy` metadata in `catalog/state-catalog.json` is accurate.
3. Republish the target generated-state branch and deploy bundle.
4. Validate with deploy-bundle dry-runs and smoke checks before cutover.
