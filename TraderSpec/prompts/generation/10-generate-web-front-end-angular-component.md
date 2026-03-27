# Prompt: Generate Web-Front-End Angular Component (Pure Spec-First)

Use this prompt for the final base-case cutover after `trade-service`: `web-front-end-angular`.

## Objective

Generate `web-front-end-angular` implementation from TraderSpec requirements, without hydrating source files from root implementation.

## Inputs

- `foundation/00-traditional-to-cloud-native/specs/components/web-front-end-angular/01-functional-requirements.md`
- `foundation/00-traditional-to-cloud-native/specs/components/web-front-end-angular/02-non-functional-requirements.md`
- `foundation/00-traditional-to-cloud-native/specs/components/web-front-end-angular/03-technical-specification.md`
- `foundation/00-traditional-to-cloud-native/specs/components/web-front-end-angular/04-verification-checklist.md`
- `catalog/component-spec.csv` row for `web-front-end-angular`

## Generation Constraints

- Preserve Angular route/component/service behavior for baseline trade workflow.
- Preserve endpoint mapping compatibility for account/reference-data/trade-service/position-service/trade-feed.
- Preserve live updates from trade-feed subscriptions for trade and position blotters.
- Preserve baseline local runtime contract (`npm run start` on port `18093`).
- Do not alter upstream service contracts in this step.

## Deliverables

- Generated component in `codebase/generated-components/web-front-end-angular-specfirst`.
- Runtime README and npm package manifest/scripts.
- Overlay startup + validation commands for mixed mode.

## Acceptance Criteria

- Verification checklist passes.
- Mixed-mode environment runs with generated Angular frontend + previously cut-over generated services.
- End-to-end GUI trade workflow remains functionally compatible.
