---
title: ADR-004 Lightweight Baseline Infra and Replaceability
slug: /adr/004-prefer-lightweight-default-infra-and-swappable-components
status: accepted
date: 2026-03-29
decision-makers: Dov Katz, TraderX maintainers
consulted: Core contributors
informed: TraderX users and contributors
---

# Prefer Lightweight Default Infrastructure and Explicit Replaceability in Baseline

## Context and Problem Statement

The baseline state must be runnable by users with minimal local setup and without requiring heavy infrastructure installation. Using production-grade infrastructure by default (for example, Kafka clusters and heavyweight database setups) raises onboarding cost and conflicts with the goal of fast experimentation.

At the same time, the architecture must not lock users into toy technologies. The project should make it clear that messaging, storage, and runtime components are replaceable through spec-driven evolution.

## Decision Drivers

* Minimize friction for first-time local runs.
* Avoid requiring complex external infrastructure for baseline usage.
* Preserve ability to swap infrastructure for functional or non-functional reasons.
* Keep learning-path transitions explicit and measurable.
* Support spec-driven regeneration across infrastructure choices.

## Considered Options

* Use production-grade infrastructure by default in baseline.
* Use lightweight local defaults and define replacement paths in specs.
* Provide no default infrastructure and require users to choose everything up front.

## Decision Outcome

Chosen option: "Use lightweight local defaults and define replacement paths in specs", because it optimizes for accessibility while preserving architecture evolution and component replaceability.

### Consequences

* Good, because baseline setup is simple and fast for most users.
* Good, because users can run and inspect behavior without specialized platform operations.
* Good, because later learning paths can intentionally introduce Kafka, stronger databases, or other infrastructure upgrades as explicit changes.
* Bad, because baseline defaults are not intended for production characteristics.
* Bad, because docs must clearly communicate that infrastructure choices are educational defaults, not universal recommendations.

### Confirmation

Decision compliance is confirmed when:

* baseline runtime can start with lightweight local dependencies,
* specs describe upgrade paths for messaging and persistence engines,
* generated implementations keep infrastructure boundaries explicit enough to swap components, and
* learning-path documentation identifies where and why each infrastructure substitution is introduced.

## Pros and Cons of the Options

### Use production-grade infrastructure by default in baseline

* Good, because production-like behavior is available from day one.
* Good, because fewer later infrastructure migrations are required.
* Bad, because onboarding complexity is significantly higher.
* Bad, because it increases operational burden for users who only want to learn core flows.

### Use lightweight local defaults and define replacement paths in specs

* Good, because it is approachable for beginners and fast to run locally.
* Good, because it supports progressive enhancement through explicit spec changes.
* Neutral, because baseline defaults intentionally trade robustness for accessibility.
* Bad, because users need clear guidance to move to stronger infrastructure.

### Provide no default infrastructure and require users to choose everything up front

* Good, because maximum flexibility is preserved.
* Neutral, because advanced users can tailor the stack immediately.
* Bad, because newcomer onboarding becomes ambiguous and fragmented.
* Bad, because cross-user reproducibility suffers.

## More Information

This decision complements the intentional legacy-shaped baseline decision and informs future learning-path deltas for containerization, messaging hardening, and database modernization.
