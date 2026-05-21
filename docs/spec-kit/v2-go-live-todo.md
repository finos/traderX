---
title: "TraderX v2.0 Go-Live TODO"
---

# TraderX v2.0 Go-Live TODO

Status: draft working checklist for post-merge execution.
Created: 2026-05-21

## Decisions (Current Direction)

- Hosting: retire Netlify hosting for docs and use GitHub Pages as the single docs host.
- Domain strategy: prefer custom domain on top of GitHub Pages (recommended: `traderx.finos.org`) instead of exposing raw `finos.github.io/traderX` as the canonical URL.
- Generated docs branch links: add an override mechanism for authoring branch links in generated docs. Default should come from a configured default branch value, with explicit override for preview/PR builds.

## Go-Live Checklist

1. Docs cleanup to reference `main` as canonical authoring branch.
1.1 Remove/replace the renovation banner with launch messaging (for example "Welcome to the new TraderX") and optional engineering-blog link.
2. Create and merge the major PR from `feature/agentic-renovation` to `main`.
3. Finalize docs hosting on GitHub Pages:
- switch Pages deploy trigger to `main`
- remove Netlify dependency from release path
- decide and apply canonical docs domain (`finos.github.io/traderX` vs custom domain)
- set `DOCUSAURUS_URL` and `DOCUSAURUS_BASE_URL` to match the final domain choice
4. Protect generated branches (`code/generated-state-*`) so only maintainers can push.
5. Add CI-driven generated-state publication pipeline (maintainer manual regen/push is interim model).
6. Improve contributor model documentation for spec-first + generated-branch workflow.
7. Add dynamic target-branch support for generated code/docs links to improve local/PR preview simulation.

## Generator Override Proposal (Implementation Target)

- Add optional env var `TRADERX_SOURCE_AUTHORING_BRANCH` and optional CLI flag `--source-authoring-branch <branch>` to `pipeline/generate-state-docs-from-catalog.mjs`.
- Resolution order:
1. CLI flag
2. `TRADERX_SOURCE_AUTHORING_BRANCH`
3. default value from repo config (target: `main`)
- Keep current behavior deterministic in CI by explicitly setting one value in workflow env.

