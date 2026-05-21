---
title: "April 20, 2026: Why Our TraderX + Sail Migration to @morgan-stanley/fdc3-web Failed (and What We Learned)"
slug: /blog/2026-04-20-fdc3-web-migration-retrospective
---

# Why Our TraderX + Sail Migration to `@morgan-stanley/fdc3-web` Failed (and What We Learned)

This post documents a real migration attempt in state `014-fdc3-intent-interoperability`: replacing our working FDC3 integration path with `@morgan-stanley/fdc3-web` across TraderX and Sail demo apps.

It did not meet our success criteria for demo reliability, and we reverted to the prior path.

## Process Transparency

An explicit admission up front:

I drove this migration based on specs/docs and functional expectations, but I did not personally hand-write the FDC3 integration code. I relied on LLM-assisted implementation and focused my effort on functional testing, log analysis, and iterative feedback to converge on working behavior.

That accelerated iteration, but it also exposed where generated code can be insufficient without deep host/runtime lifecycle understanding.

## Success Criteria We Used

We considered the migration successful only if all of the following held consistently:

1. TraderX row selection broadcasts `fdc3.instrument`.
2. TradingView widgets react in the same channel/context.
3. Polygon news reacts in the same channel/context.
4. TraderX Intent Launcher resolves current channel + ticker and can trigger TraderX ticket flows.
5. Sail app discovery shows TraderX as an existing app where expected.

## What We Observed

Some interoperability signals looked healthy:

- `getCurrentChannelRequest/Response` worked.
- `getCurrentContextRequest/Response` worked.
- Channel IDs were returned correctly.

But end-to-end behavior was unstable due to initialization failures and timing races:

- `IdentityValidationHandler: Identity validation timed out`
- `The Desktop Agent didn't respond to ID validation within 5 seconds`
- `Discovery results: [{ status: "rejected", reason: "ErrorOnConnect" }]`
- `TradingView failed to initialize`
- `Polygon failed to initialize`
- listener registration timeouts followed by "best effort" paths

In other words: transport-level activity existed, but app-level readiness was not durable.

## Root Cause Categories

### 1) Lifecycle mismatch between host startup and strict validation windows

`@morgan-stanley/fdc3-web` behavior in our flow was stricter around identity validation/connection timing than our Sail startup sequence could reliably satisfy on first attempt.

When first connect failed (`ErrorOnConnect`), app widgets often remained disconnected.

### 2) One-shot initialization in widget code

TradingView and Polygon widgets initially performed a single connection attempt and then logged failure.

Without reconnect/backoff, transient startup lag became persistent app failure.

### 3) Identity URL instability during experiments

At one point, URL query seeding/cache-busting was introduced to avoid stale session collisions. That caused handshake errors in Sail's proxy path (`Illegal handshake attempt` style behavior), indicating identity contract mismatch for this host.

### 4) Channel topology confusion in seeded demo state

A seeded layout had multiple TraderX instances on different tabs/channels. Broadcasts from one TraderX were valid, but consumers on another channel did not react, creating a false appearance of protocol failure.

## Why This Is Not Simply a "Spec Compliance" Story

FDC3 standardizes interop semantics (`broadcast`, context listeners, intents, channels), but not every host/discovery/bootstrap implementation detail:

- discovery handshake timing,
- identity validation policy,
- reconnect strategy,
- listener re-registration behavior,
- iframe/proxy boot choreography.

Two libraries can be FDC3-compliant and still behave very differently under real startup conditions.

## What We Changed to Restore Reliability

After reverting to the established Sail-aligned path, we hardened the runtime:

1. Stable identity URL handling for TraderX.
2. Seeded state updates to avoid stale session/panel IDs.
3. Demo layout normalization so TraderX + TradingView + Polygon boot on the same tab/channel.
4. Reconnect/backoff logic in TradingView/Polygon widget initialization instead of fail-fast one-shot init.

With these changes, the functional criteria were met again in repeated local validation runs.

## Practical Guidance for Teams Attempting Similar Migrations

Treat an FDC3 library swap as a platform integration change, not a package replacement.

Validate explicitly:

1. cold-start handshake behavior,
2. identity validation timeout behavior,
3. reconnect/listener re-registration after transient failures,
4. seeded layout/channel defaults,
5. stale local-storage state interactions.

## Final Takeaway

This migration attempt was not successful in its target form, but it produced useful engineering knowledge:

- spec-compliant APIs are necessary but not sufficient for runtime reliability,
- host lifecycle assumptions matter as much as API surface,
- LLM-assisted implementation can accelerate delivery but still requires rigorous integration testing and operator-driven diagnostics.

For now, we prioritize deterministic demo behavior on the proven integration path and may revisit `@morgan-stanley/fdc3-web` later behind a host-aware adapter.

## References

- State spec pack: [/specs/fdc3-intent-interoperability](/specs/fdc3-intent-interoperability)
- Learning guide: [/docs/learning/state-014-fdc3-intent-interoperability](/docs/learning/state-014-fdc3-intent-interoperability)
- FDC3 standard background: [fdc3.finos.org](https://fdc3.finos.org)

