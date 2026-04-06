---
title: ADR-008 Convergence State Model (C0-C3)
slug: /adr/008-convergence-state-model
status: accepted
date: 2026-04-06
decision-makers: Dov Katz, TraderX maintainers
consulted: Core contributors
informed: TraderX users and contributors
---

# Adopt Explicit Convergence States (C0-C3) with Single-Parent Publish Lineage

## Context and Problem Statement

TraderX now contains multiple tracks (architecture, functional, and platform/devex). We need a predictable way to:

- preserve clean single-parent branch ancestry for generated code publishing,
- show where tracks converge into recommended jump-off points,
- avoid ad hoc multi-parent lineage that complicates automation and compareability.

## Decision Drivers

* Keep generated branch ancestry linear and reproducible.
* Make “best starting points” explicit for future feature design.
* Preserve track-level learning visibility without forcing merge ancestry.
* Keep state model machine-validated through CI gates.

## Considered Options

* Keep only plain state lineage (`previous`) and no explicit convergence semantics.
* Allow true multi-parent lineage for publish ancestry.
* Keep single-parent publish lineage and add explicit convergence metadata plus dotted-line parents.

## Decision Outcome

Chosen option: "Keep single-parent publish lineage and add explicit convergence metadata plus dotted-line parents".

### Consequences

* Good, because generated branch ancestry remains deterministic and CI/publish tooling stays simple.
* Good, because documentation can still show where tracks converge (`C0`, `C1`, `C2`, `C3`).
* Good, because maintainers can recommend stable jump-off points for new work.
* Bad, because convergence context now requires additional metadata governance.
* Bad, because dotted-line parents must be documented carefully to avoid confusion with publish ancestry.

### Confirmation

Decision compliance is confirmed when:

* every state in `catalog/state-catalog.json` defines:
  - `convergenceLevel`,
  - `isConvergence`,
  - `dottedParents`,
  - `primaryLineageRole`.
* `previous` remains single-parent (`length <= 1`) for all states.
* non-convergence states do not define dotted parents.
* convergence states include `system/convergence-rationale.md`.
* generated learning docs and visual graphs show convergence metadata and dotted-line lineage.

## Pros and Cons of the Options

### Plain lineage only

* Good, because metadata is minimal.
* Bad, because recommended convergence checkpoints are implicit and easy to miss.
* Bad, because parallel-track reasoning is harder for contributors.

### True multi-parent publish lineage

* Good, because ancestry can mirror conceptual convergence.
* Bad, because publish and compare tooling becomes significantly more complex.
* Bad, because branch history maintenance cost increases.

### Single-parent lineage + convergence metadata

* Good, because it balances tooling simplicity with explicit convergence semantics.
* Good, because docs can visualize both publish lineage and conceptual convergence.
* Neutral, because additional metadata/governance is required.

## More Information

Related artifacts:

* Catalog source of truth: `/catalog/state-catalog.json`
* Convergence reference: `/docs/spec-kit/convergence-states`
* Visual learning graph: `/docs/learning-paths`
