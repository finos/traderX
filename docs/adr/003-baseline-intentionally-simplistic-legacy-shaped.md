---
title: ADR-003 Intentional Legacy-Shaped Baseline
slug: /adr/003-baseline-intentionally-simplistic-legacy-shaped
status: accepted
date: 2026-03-29
decision-makers: Dov Katz, TraderX maintainers
consulted: Core contributors
informed: TraderX users and contributors
---

# Keep the First Learning State Intentionally Simplistic and Legacy-Shaped

## Context and Problem Statement

The first TraderX learning state is the baseline from which users will evolve architecture and quality characteristics across multiple learning paths. If this baseline starts with mature modern practices already in place, users lose the ability to understand why those practices were introduced and what they changed.

The project needs a starting state that resembles legacy-style distributed applications commonly found in larger enterprises: chatty service calls, minimal platform automation, and limited cross-cutting engineering practices.

## Decision Drivers

* Preserve educational contrast between baseline and later improved states.
* Represent realistic legacy starting conditions.
* Minimize conceptual load for first-time users.
* Enable clear, incremental demonstrations of DevEx, NFR, and functional evolution.
* Avoid prematurely constraining future learning-path design.

## Considered Options

* Start with a production-grade modern baseline.
* Start with a heavily mocked single-process demo.
* Start with a simple distributed baseline that is intentionally legacy-shaped.

## Decision Outcome

Chosen option: "Start with a simple distributed baseline that is intentionally legacy-shaped", because it best supports progressive learning and makes the value of each subsequent architecture or quality improvement explicit.

### Consequences

* Good, because learners can see concrete before/after impact for each improvement step.
* Good, because the baseline matches conditions many enterprise teams actually inherit.
* Good, because later state transitions can be mapped to specific pain points rather than abstract goals.
* Bad, because the baseline intentionally violates some modern best practices.
* Bad, because some users may initially mistake baseline limitations for target end-state guidance.

### Confirmation

Decision compliance is confirmed when baseline documentation and generated runtime behavior show:

* direct multi-service communication patterns without advanced platform abstractions,
* no mandatory containerization, ingress, or auth assumptions in the first state, and
* explicit learning-path references showing where these concerns are introduced later.

## Pros and Cons of the Options

### Start with a production-grade modern baseline

* Good, because immediate technical quality is higher.
* Good, because fewer remediation steps are needed before real-world deployment.
* Bad, because it reduces educational visibility into why improvements matter.
* Bad, because it increases upfront complexity for beginners.

### Start with a heavily mocked single-process demo

* Good, because setup complexity is minimal.
* Neutral, because local onboarding can be fast.
* Bad, because it fails to represent distributed-system realities.
* Bad, because later transitions to realistic architecture become abrupt.

### Start with a simple distributed baseline that is intentionally legacy-shaped

* Good, because it balances realism and approachability.
* Good, because it creates a clear narrative for incremental upgrades.
* Neutral, because some baseline imperfections are intentional by design.
* Bad, because explicit communication is needed to avoid confusion about quality targets.

## More Information

This decision is paired with the minimal-runtime dependency decision to keep baseline setup accessible while preserving replaceability of infrastructure choices.
