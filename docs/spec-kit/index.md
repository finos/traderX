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

Create a new planned state pack from template:

```bash
bash pipeline/scaffold-state-pack.sh <NNN-state-name> --title "<Title>" --previous <prior-state-id> --track <devex|nonfunctional|functional>
```

## New Contributor Path

1. Read the source-of-truth map:
   - `/docs/spec-kit/spec-kit-portal`
2. Run the baseline from specs:
   - `/docs/spec-kit/spec-kit-generation-guide`
3. Understand validation and parity gates:
   - `/docs/spec-kit/spec-kit-workflow`
4. Understand generated-code branch publishing:
   - `/docs/spec-kit/generated-state-branches`
5. Follow patch-set implementation workflow:
   - `/docs/spec-kit/patchset-authoring`
6. Browse state-specific architecture and flow docs:
   - `/docs/spec-kit/state-docs`
7. Browse developer-focused generated-code guides per state:
   - `/docs/learning`
8. Browse core artifacts:
   - `/specs`
   - `/specify`
9. Plan future-state transitions:
   - `/docs/spec-kit/spec-kit-learning-path-strategy`
   - `/docs/learning-paths`

## Where Is The Generated Code?

All state code is available in this repository as generated-state branches/tags, while `main` keeps the spec-first source of truth.

- Branch pattern: `code/generated-state-*`
- Tag pattern: `generated/<state-id>/vN`
- Publish mapping source: `catalog/state-catalog.json`

Browse directly:

- [Generated-State Branches on GitHub](https://github.com/finos/traderX/branches/all?query=code%2Fgenerated-state-)
- [Generated-State Tags on GitHub](https://github.com/finos/traderX/tags?query=generated%2F)
- [State Catalog (`catalog/state-catalog.json`)](https://github.com/finos/traderX/blob/main/catalog/state-catalog.json)
- [Generated State Branches Guide](/docs/spec-kit/generated-state-branches)

## What Is Canonical

- SpecKit scaffold and governance: `/.specify/**`
- Baseline feature pack: `/specs/001-baseline-uncontainerized-parity/**`
- Learning-path definitions and state map: `/docs/learning-paths/**` and `/catalog/learning-paths.yaml`
- Generation/runtime orchestration: `/pipeline/**` and `/scripts/**`

## Why This Structure Works

- Requirements and stories are explicit and reviewable.
- Code generation is reproducible and test-gated.
- State transitions are auditable through numbered feature packs.
- Learning paths stay consistent with the same baseline contracts and behaviors.
- Parallel or conflicting state options can coexist with low maintenance overhead because specs are canonical and code is generated.

## Learning Path Rule Set

- DevEx and non-functional paths should primarily layer NFR and operational constraints.
- Functional paths may introduce FR deltas, but must preserve baseline compatibility unless explicitly versioned.
- Every transition should include traceability updates and conformance checks before promotion.

Use `/docs/spec-kit/spec-kit-learning-path-strategy` for the concrete transition template.
