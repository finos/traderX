---
title: "April 10, 2026: Custom Overlay Model for Environment-Specific TraderX"
slug: /blog/2026-04-10-custom-overlay-model-and-example
---

# Custom Overlay Model for Environment-Specific TraderX

TraderX now documents a clear customization path for teams that need environment-specific runtime, package, messaging, or governance constraints while keeping upstream TraderX clean.

## Why Overlay Instead of Fork

- Keep upstream state packs and generation logic as the public source of truth.
- Keep environment-specific changes in a separate overlay repository.
- Regenerate and republish snapshots in a controlled, reproducible way.

This avoids long-term drift and keeps contributions focused on upstream specs when a change should benefit everyone.

## Recommended Structure

The canonical starter is:

- `examples/custom-overlay-template/`

The documented target model is:

- `upstream/traderX` as a pinned submodule
- overlay-owned `profiles/`, `states/`, `transforms/`, and `runtime/`
- overlay-owned `pipeline/generate-state.sh` and `pipeline/publish-state-branch.sh`

## Suggested Example Custom Rule

A practical example for constrained environments:

- runtime policy disallows default local database images
- each generated state uses a managed database endpoint pattern
- connection/auth material is injected through environment setup scripts

This pattern is reflected in template examples so teams can adapt the mechanism without copying environment-specific values into upstream docs.

## Key Operational Rules

- Treat generated outputs as reproducible artifacts, not hand-edited code.
- Keep transform scripts idempotent.
- Apply transforms after layout copy steps that overwrite target directories.
- Enforce one-commit-per-generated-state-branch publishing in overlay repos as well.

## Where To Start

- Getting started: [/docs/spec-kit/getting-started-with-traderx](/docs/spec-kit/getting-started-with-traderx)
- Customization hub: [/docs/spec-kit/customizing-traderx](/docs/spec-kit/customizing-traderx)
- Overlay architecture contract: [/docs/spec-kit/custom-overlay-architecture](/docs/spec-kit/custom-overlay-architecture)
- Environment and integration guidance: [/docs/spec-kit/custom-environments-guide](/docs/spec-kit/custom-environments-guide)
