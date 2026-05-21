---
title: ADR-002 Generated State Branching Strategy
slug: /adr/002-generated-state-branching-strategy
status: accepted
date: 2026-03-29
decision-makers: Dov Katz, TraderX maintainers
consulted: Core contributors
informed: TraderX users and contributors
---

# Use a Two-Surface Branching Strategy for Spec Sources and Generated Code States

## Context and Problem Statement

TraderX must support two valid consumer modes:

1. contributors who evolve requirements and generation logic through GitHub Spec Kit artifacts, and
2. developers who want a directly runnable code snapshot for a specific learning state.

Keeping only generated code in `main` would reduce clarity around source-of-truth requirements. Keeping only spec artifacts in `main` would make it harder for code-first users to consume state snapshots quickly.

The decision is how to organize branches so the repository stays spec-first while still publishing easy-to-consume generated state outputs.

## Decision Drivers

* Preserve specs as the canonical source of truth.
* Provide discoverable generated snapshots for code-first users.
* Avoid creating and maintaining multiple repositories.
* Keep CI and docs workflows manageable.
* Support future learning-path state transitions with minimal operational overhead.

## Considered Options

* Single branch with only generated code.
* Two separate repositories (one spec repo, one generated-code repo).
* Single repository with spec-first `main` plus dedicated generated-state branches.

## Decision Outcome

Chosen option: "Single repository with spec-first `main` plus dedicated generated-state branches", because it preserves one project identity while separating authoring concerns (specification) from distribution concerns (generated runnable snapshots).

### Consequences

* Good, because `main` remains cleanly focused on specs, tooling, and governance.
* Good, because generated branches can be consumed without needing full Spec Kit context.
* Good, because branch diffs between generated states become a practical learning artifact.
* Bad, because release discipline is required to ensure generated branches are reproducible from `main`.
* Bad, because documentation must clearly explain the difference between spec-source and generated-state branches.

### Confirmation

Decision compliance is confirmed when all of the following are true:

* `main` stores canonical specs and generation pipelines, not checked-in generated outputs.
* Generated outputs are published in dedicated branches using an explicit naming convention.
* Each generated branch references the source spec commit and generation command set used.
* Smoke tests pass for generated runtime flows before a generated branch is published.

## Pros and Cons of the Options

### Single branch with only generated code

* Good, because code-first consumption is straightforward.
* Neutral, because branch management overhead is low.
* Bad, because requirements and planning intent are no longer first-class.
* Bad, because regeneration provenance becomes weak.

### Two separate repositories (one spec repo, one generated-code repo)

* Good, because separation of concerns is explicit.
* Good, because access controls and release cadence can differ by repo.
* Bad, because cross-repo synchronization and governance overhead increases.
* Bad, because contributors must navigate two project homes.

### Single repository with spec-first `main` plus dedicated generated-state branches

* Good, because it keeps one canonical project with clear authoring vs distribution surfaces.
* Good, because it supports both spec-driven and code-first contributor workflows.
* Neutral, because branch conventions and automation must be maintained.
* Bad, because process quality depends on consistent release hygiene.

## More Information

Operational notes:

* Generated-state branch naming should be documented centrally (for example, `generated/<state>/<version>`).
* Branch publish flow should include generation commands, validation output, and traceability links back to source specs.
