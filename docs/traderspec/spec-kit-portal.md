---
title: Spec Kit Portal
---

# Spec Kit Portal

This is the single map for where Spec Kit artifacts live in TraderX and how they are used for generation.

## Published Sources

The portal publishes three repository sources:

1. Root feature packs under `specs/**`
2. Root Spec Kit scaffold under `.specify/**`
3. Migration execution records under `TraderSpec/**`

## Browse in Docusaurus

- Root specs catalog: `/traderspec-specs/specs`
- Baseline feature pack: `/traderspec-specs/specs/baseline-uncontainerized-parity`
- OpenAPI API Explorer: `/traderspec-specs/api`
- `.specify` constitution and templates: `/traderspec-specs/specify`
- Generation operator guide: `/docs/traderspec/spec-kit-generation-guide`
- Migration TODO: `/traderspec-specs/migration-todo`
- Migration Blog: `/traderspec-specs/migration-blog`

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

These extensions are intentional and sit on top of, not instead of, the core Spec Kit workflow.
