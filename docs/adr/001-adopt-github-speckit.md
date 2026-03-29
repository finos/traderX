---
title: ADR-001 Adopt GitHub Spec Kit
slug: /adr/001-adopt-github-speckit
status: accepted
date: 2026-03-29
decision-makers: Dov Katz, TraderX maintainers
consulted: Core contributors, documentation maintainers
informed: TraderX users and contributors
---

# Adopt GitHub Spec Kit as the Canonical Specification Workflow

## Context and Problem Statement

TraderX is being repositioned as a spec-driven learning platform where implementation is generated from requirements instead of copied from legacy source. The repository previously mixed historical implementation guidance with multiple migration approaches, which made the project difficult to understand and evolve consistently.

The core decision is how to standardize specification authoring, planning, task execution, traceability, and verification so future state transitions can be implemented from specs with predictable quality.

## Decision Drivers

* Need one canonical specification workflow for requirements, stories, and implementation planning.
* Need stronger traceability from system-level requirements to generated component behavior.
* Need onboarding simplicity for new contributors.
* Need compatibility with AI-assisted, iterative generation workflows.
* Need documentation that can expose specs and governance artifacts directly in the docs portal.

## Considered Options

* Continue with custom TraderSpec-only scripts and local conventions.
* Build a fully custom internal specification framework.
* Adopt GitHub Spec Kit as the canonical workflow and align repo structure/process around it.

## Decision Outcome

Chosen option: "Adopt GitHub Spec Kit as the canonical workflow and align repo structure/process around it", because it provides an opinionated, documented, and repeatable path for moving from requirements to implementation while preserving traceability and governance artifacts.

### Consequences

* Good, because contributors can follow a known workflow (`specify` -> `plan` -> `tasks` -> implement) with less ambiguity.
* Good, because specs, constitution, and execution artifacts become first-class and easier to review.
* Good, because generation quality can be improved by enriching requirements and non-functional constraints instead of changing ad hoc scripts.
* Bad, because existing legacy docs and workflows must be clearly deprecated or removed to avoid confusion.
* Bad, because initial migration overhead is non-trivial and requires disciplined document maintenance.

### Confirmation

Decision compliance is confirmed when all of the following are true:

* Root Spec Kit artifacts remain the source of truth (`.specify/**`, `specs/**`).
* Generated baseline components can be produced and validated from spec-first pipelines.
* Docusaurus nav exposes Spec Kit artifacts and hides deprecated legacy guide material.
* CI gate scripts for Spec Kit readiness and coverage continue to pass.

## Pros and Cons of the Options

### Continue with custom TraderSpec-only scripts and local conventions

* Good, because migration effort is lowest in the short term.
* Neutral, because existing contributors already know the current scripts.
* Bad, because it keeps process semantics implicit and harder for new contributors to follow.
* Bad, because it reduces external alignment and discoverability.

### Build a fully custom internal specification framework

* Good, because the process can be tailored exactly to TraderX.
* Neutral, because it can model learning-path-specific needs deeply.
* Bad, because long-term maintenance cost is high.
* Bad, because governance and conventions become project-specific and harder to transfer.

### Adopt GitHub Spec Kit as the canonical workflow and align repo structure/process around it

* Good, because it provides a recognized structure for specs, planning, and tasks.
* Good, because it fits the goal of regenerating code from explicit requirements and constraints.
* Neutral, because some TraderX-specific conventions still need local adaptation.
* Bad, because migration requires cleanup of legacy content and re-training contributors.

## More Information

Primary reference: [GitHub Spec Kit](https://github.github.com/spec-kit/index.html)

Related repository decisions:

* Branching strategy for generated state snapshots.
* Deprecation of pre-SpecKit guide material under `docs/guide/**`.
