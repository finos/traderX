---
title: SpecKit Getting Started
---

# SpecKit Getting Started

This project is built so a contributor can regenerate the baseline system from requirements and then evolve future states through SpecKit feature packs.

The baseline state is intentionally **pre-Docker / pre-ingress**:

- nine local processes
- fixed startup order
- fixed default ports
- explicit cross-origin CORS behavior

From this state, we generate code from specs and move forward by adding controlled FR/NFR deltas.

## New Contributor Path

1. Read the source-of-truth map:
   - `/docs/traderspec/spec-kit-portal`
2. Run the baseline from specs:
   - `/docs/traderspec/spec-kit-generation-guide`
3. Understand validation and parity gates:
   - `/docs/traderspec/spec-kit-workflow`
4. Understand generated-code branch publishing:
   - `/docs/traderspec/generated-state-branches`
5. Browse core artifacts:
   - `/specs`
   - `/foundation`
   - `/specify`
6. Review current migration status:
   - `/migration/migration-todo`
   - `/migration/migration-blog`
7. Plan future-state transitions:
   - `/docs/traderspec/spec-kit-learning-path-strategy`
   - `/docs/learning-paths`

## What Is Canonical

- SpecKit scaffold and governance: `/.specify/**`
- Baseline feature pack: `/specs/001-baseline-uncontainerized-parity/**`
- Foundation requirements corpus: `/foundation/00-traditional-to-cloud-native/**`
- Learning-path definitions: `/tracks/**`
- Generation/runtime orchestration: `/pipeline/**` and `/scripts/**`

## Why This Structure Works

- Requirements and stories are explicit and reviewable.
- Code generation is reproducible and test-gated.
- State transitions are auditable through numbered feature packs.
- Learning paths stay consistent with the same baseline contracts and behaviors.

## Learning Path Rule Set

- DevEx and non-functional paths should primarily layer NFR and operational constraints.
- Functional paths may introduce FR deltas, but must preserve baseline compatibility unless explicitly versioned.
- Every transition should include traceability updates and conformance checks before promotion.

Use `/docs/traderspec/spec-kit-learning-path-strategy` for the concrete transition template.
