---
title: Spec Kit Portal
---

# Spec Kit Portal

This is the single map for where Spec Kit artifacts live in TraderX and how they are used for generation.

## Published Sources

The portal publishes three repository sources:

1. Root feature packs under `specs/**`
2. Root Spec Kit scaffold under `.specify/**`
3. Generated runtime/doc artifacts under `generated/**` (ephemeral outputs)

## Browse in Docusaurus

- Root specs catalog: `/specs`
- Baseline feature pack: `/specs/baseline-uncontainerized-parity`
- State docs map (flows + architecture): `/docs/spec-kit/state-docs`
- Learning guides for generated code states: `/docs/learning`
- OpenAPI API Explorer: `/api`
- Project ADRs: `/docs/adr`
- `.specify` constitution and templates: `/specify/memory/constitution`
- Generation operator guide: `/docs/spec-kit/spec-kit-generation-guide`
- Generated-state branch model: `/docs/spec-kit/generated-state-branches`
- Learning-path visuals: `/docs/spec-kit/visual-learning-graphs`

## Official GitHub Spec Kit

There is currently no official Docusaurus plugin from GitHub Spec Kit.

Official references:

- Spec Kit docs: [https://github.github.com/spec-kit/index.html](https://github.github.com/spec-kit/index.html)
- Spec Kit quickstart: [https://github.github.com/spec-kit/quickstart.html](https://github.github.com/spec-kit/quickstart.html)
- Spec Kit repository: [https://github.com/github/spec-kit](https://github.com/github/spec-kit)

## How This Repo Maps to Spec Kit

Core alignment:

- `.specify/` initialized and active
- numbered root feature packs under `specs/NNN-*`
- `spec.md` -> `plan.md` -> `tasks.md` flow in baseline pack
- constitution and templates in active use
- CI/root gates for feature-pack and branch/feature resolution checks

Repo-specific extensions:

- manifest-driven synthesis compiler and component generators
- conformance packs and semantic compare harness
- parity smoke-test gates for runtime validation
- optional `learn` community extension for richer learning-material authoring workflows

These extensions are intentional and sit on top of, not instead of, the core Spec Kit workflow.
