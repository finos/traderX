---
title: TraderX + GitHub SpecKit Migration (Technical Retrospective)
date: 2026-03-29
description: A detailed write-up of the TraderX migration to GitHub SpecKit, including false starts, process corrections, branch strategy, and lessons learned.
---

# TraderX + GitHub SpecKit Migration (Technical Retrospective)

Published: **Sunday, March 29, 2026**

For the last 2.5 years, TraderX has had one persistent tension: keep the project simple and approachable for learners, while receiving a steady flow of good ideas and PRs that naturally push toward more production-style complexity.

The hardest part was never a shortage of contributions. The hard part was fitting those contributions into a structure that preserved the project's educational simplicity.

## The Core Challenge

We needed to support all of the following:

- A baseline that feels lightweight and accessible.
- Advanced paths for platform and non-functional evolution.
- A visual learning portal that maps state transitions clearly.
- A sustainable maintenance model for a small maintainer group.

In practice, we were already feeling the strain of dependency maintenance on one line of code. Maintaining many parallel long-lived branches with different architectural maturity levels was not realistic.

## The First Attempt: High Momentum, Wrong Foundation

When I initially worked with an LLM on this direction, the early results looked great:

- It migrated component-by-component toward spec-first flow.
- It could run generated components alongside traditional components.
- It advanced step-by-step to full-system parity.
- It produced progress documentation, including Mermaid visuals on Docusaurus.

From the outside, it looked like a breakthrough.

Under the hood, it was not.

The model had effectively invented its own flavor of "spec-driven development" while labeling it "speckit." It was inspired by SpecKit, but not aligned with **GitHub SpecKit** conventions and workflow.

Even worse, some of the so-called generation scripts were effectively large shell scripts that dumped file contents into targets. That created a convincing facade, but not a trustworthy or maintainable generation mechanism.

## Reset and Migration to Real GitHub SpecKit

At that point, I reset the direction and enforced stricter constraints:

- Learn and follow official GitHub SpecKit patterns end-to-end.
- Document a migration plan from fake speckit artifacts to canonical SpecKit structure.
- Track retirement of legacy docs/scripts that no longer matched the target model.
- Keep commits small and continuous in a dedicated migration branch.

This process was not smooth. It required close oversight, repeated corrections, and explicit TODO planning to keep the agent from drifting into plausible-but-wrong shortcuts.

## What Changed in Practice

After that correction phase, we reached a clean baseline where state-oriented specs became the source of truth and code became generated output.

We first validated that the generated harness could reproduce existing behavior for the initial baseline state. Then the process became more interesting: we layered additional state transitions through spec-defined deltas and regenerated.

## Branch and State Strategy

We chose to keep canonical spec authoring in the main renovation branch, and publish generated code snapshots as separate state branches:

- `code/generated-state-001-baseline-uncontainerized-parity`
- `code/generated-state-002-edge-proxy-uncontainerized`
- `code/generated-state-003-containerized-compose-runtime`
- `code/generated-state-004-kubernetes-runtime`
- `code/generated-state-005-radius-kubernetes-platform`
- `code/generated-state-006-tilt-kubernetes-dev-loop`

This gave us a useful split:

- Developers who just want code can read state branches directly.
- Maintainers solve the harder meta-problem in the spec branch, then regenerate.

As cross-cutting changes land (README improvements, learning graph updates, docs cleanup), we can regenerate all states quickly and keep them aligned.

## Why This Is Better

This model makes contribution intake different:

- It is trickier in one sense because contributions should target specs and state deltas, not ad hoc code drops.
- It is much easier in another sense because intent, scope, and compatibility are explicit.

For maintainers, the tradeoff is worth it. We gain speed, clarity, and reproducibility.

For learners, we can preserve a simple starting point while still exposing richer paths without collapsing everything into one intimidating codebase.

## What Is Still Open

We still need to define some transition boundaries more clearly, for example:

- Where to shift from simple baseline runtime into mature containerized paths.
- When to introduce heavier NFR tracks such as observability and service mesh.
- How to layer functional expansions (for example advanced pricing engines) while keeping state coherence.
- How to present this whole model so newcomers are not overwhelmed on first contact.

One likely next move is a "pre-phase-0" explanation state that is intentionally simple and onboarding-focused.

## Where to Inspect the Work

- Renovation branch: [feature/agentic-renovation](https://github.com/finos/traderX/tree/feature/agentic-renovation)
- Commit history: [feature/agentic-renovation commits](https://github.com/finos/traderX/commits/feature/agentic-renovation)
- Generated state-code branches: [search `code/generated-state-*`](https://github.com/finos/traderX/branches/all?query=code%2Fgenerated-state-)

The commit trail and generated-state branches show how this evolved in real time, including course-corrections and cleanup decisions that were necessary to move from "looks like it works" to "this is a real and sustainable foundation."
