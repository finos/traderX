---
title: Spec Kit Portal
---

# Spec Kit Portal

This is the entrypoint for Spec Kit artifacts in TraderX.

## What Is Published

The documentation portal surfaces three local sources:

1. Root feature packs under `specs/**`
2. Root Spec Kit scaffolding under `.specify/**`
3. TraderSpec migration and legacy pointer docs under `TraderSpec/**`

## Where To Browse

- Root specs catalog: `/traderspec-specs/specs`
- Baseline feature pack: `/traderspec-specs/specs/baseline-uncontainerized-parity`
- Spec Kit constitution + template source links: `/traderspec-specs/specify`
- Migration TODO: `/traderspec-specs/migration-todo`
- Migration Blog: `/traderspec-specs/migration-blog`

## Official GitHub Spec Kit

There is currently no official Docusaurus plugin from GitHub Spec Kit.

Official references:

- Spec Kit docs: `https://github.github.com/spec-kit/index.html`
- Spec Kit quickstart: `https://github.github.com/spec-kit/quickstart.html`
- Spec Kit repository: `https://github.com/github/spec-kit`

## Conformance Status (Current)

Current implementation is aligned with the core GitHub Spec Kit workflow:

- initialized `.specify/` project scaffold
- root feature pack structure in `specs/NNN-*`
- `spec.md` + `plan.md` + `tasks.md` driven flow
- constitution and template usage
- CI quality gates for root feature-pack integrity and branch/feature resolution

Remaining gap vs strict “upstream-native” usage:

- we include project-specific synthesis/conformance pipelines beyond base Spec Kit defaults
- slash-command execution UX depends on agent tooling; in this repo we also support Codex skills wrappers
