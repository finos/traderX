# DevEx Path Spec

## Track Objective

Evolve delivery and developer workflow from traditional setup to cloud-native operations without changing core functional scope.

## Requirement Layering

- Baseline FR: inherited unchanged.
- NFR: additive per step (build speed, deploy safety, reproducibility, platform operability).

## Canonical Progression

`base-00-traditional -> 01-foundation -> 02-docker-compose -> 03-tilt-dev -> (04-kubernetes | 04-radius) -> 05-gitops`

## Prompt Entry

- `TraderSpec/prompts/generation/01-generate-step-from-spec.md`
- `TraderSpec/prompts/validation/01-validate-step-contracts.md`
