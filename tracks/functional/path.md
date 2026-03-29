# Functional Path Spec

## Track Objective

Evolve domain capabilities and user-facing features while maintaining operational and compatibility guardrails.

## Requirement Layering

- Baseline FR: inherited.
- Additional FR: allowed and explicit at functional steps.
- NFR: inherited and optionally strengthened when needed.

## Canonical Progression

`base-00-traditional -> 01-common-data-model -> 02-real-time-pricing -> (03-advanced-orders | 03-portfolio-analytics) -> (04-angular-modern | 04-micro-frontends) -> 05-event-driven`

## Prompt Entry

- `TraderSpec/prompts/generation/01-generate-step-from-spec.md`
- `TraderSpec/prompts/analysis/01-diff-step-vs-current-system.md`
