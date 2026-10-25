---
title: "Authoring incremental state lessons"
---

# Authoring incremental state lessons

Every catalog state is a chapter in a practical learning journey. Its contract belongs to the state and every incoming transition. Explain the problem before the tool, then connect an experiment to evidence the reader can interpret. A list of code changes or section headings does not constitute a lesson.

## Ownership and generation

The state author owns `specs/<state>/learning-contract.json`. The machine-readable contract is [the learning-contract JSON Schema](https://github.com/finos/traderX/blob/main/docs/.schema/learning-contract.schema.json), version 1. The catalog owns IDs, maturity, `previous`, dotted context and onward relationships. Do not infer lineage from numbering or duplicate it in a second catalog.

`pipeline/generate-state-docs-from-catalog.mjs` renders each contract at the start of the single canonical `docs/learning/state-<id>.md` guide. The same pipeline generates the chapter index and visual paths. The website adds a return link to every Markdown page within a catalog state at build time. Edit sources and regenerate; do not maintain another learner guide inside system documentation.

Run:

```bash
bash pipeline/refresh-state-docs.sh
bash pipeline/verify-spec-coverage.sh
npm --prefix website run build
```

The root coverage command validates schema, predecessor equality, stable objective identifiers, walkthrough and assessment coverage, maturity, supporting references, generated content and parity. The build verifies resolved destinations and both navigation journeys against rendered HTML. PR CI runs those same commands. A failing message names the state and the source to correct. There are no legacy exemptions.

## Required fields

| Field | Authoring responsibility |
| --- | --- |
| `version`, `state`, `title` | Use schema version 1, the catalog ID, and a chapter title that describes the learning problem. |
| `purpose`, `entryAssumptions`, `before`, `after` | Identify the audience, motivation, starting capabilities and concrete increment. |
| `concepts`, `runtimePrerequisites` | Explain unfamiliar concepts before implementation terms; separate understanding from installation. |
| `entryMode` | Use `foundation` for a state with no predecessor, `combined` for required incoming knowledge, or `alternative` for alternative routes. |
| `transitions` | Exactly one entry for each catalog `previous`: `from`, `carriesForward`, `motivation`, `increment`, `objectiveIds`, and `evidence`. Explain each parent's distinct contribution. |
| `objectives` | Stable kebab-case `id` and observable `outcome`; preserve IDs when editing wording. |
| `walkthrough` | Stable `id`, mapped `objectiveIds`, `availability`, executable `action`, meaningful `expected` observations, and local `/specs/…` `references`. Include uncertainty or failure. |
| `assessments` | Mapped `objectiveIds`, a `question` or exercise, and `guidance` explaining adequate evidence. |
| `limitations` | Explain simulation, external dependencies, omitted behavior and what the evidence cannot prove. |

Every objective needs walkthrough and assessment coverage; every transition must identify the objectives that demonstrate its increment. References must resolve to real pages. Baselines describe their entry assumptions without inventing a predecessor. At convergence explain dotted context separately from required parents. A planned state must mark every runtime exercise `unavailable`; implemented/released states must provide `available` exercises with complete instructions and assessment guidance.

The dependency-free validator implements exactly the JSON Schema keywords used by this version and rejects unsupported keywords. Adding a schema keyword requires extending its validator and tests. Minimum lengths reject empty content, but are not a measure of instructional quality.

## Human acceptance review

Before accepting a chapter, a reviewer must:

- Follow the incoming route and explain what knowledge carries forward and which assumption changes. At convergence, check every parent's contribution and whether routes combine or are alternatives.
- Run the documented walkthrough in the stated environment and record the revision, observations and uncertainty case in the PR. Confirm each observation supports its mapped objective.
- Answer the assessment using collected evidence, not the headings or a healthy status indicator. Confirm the guidance distinguishes success, rejection, pending work and unknown outcomes where relevant.
- Check concepts are introduced before tool names, prerequisites are sufficient, and simulation/external boundaries are explicit.
- Navigate homepage → Learning Guide → state → walkthrough → system material, then system material → the same guide → predecessor/next state, in the preview.

Keep review results and PR-specific evaluation reports in GitHub, outside the published learning portal. These checks cannot be replaced by automation. Runtime maturity does not imply that a newly written lesson has already been manually reviewed.
