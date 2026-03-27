# Prompt: Generate Reference-Data Component (Pure Spec-First)

Use this prompt when executing Phase 4.3 for the first pure-generated component cutover.

## Objective

Generate `reference-data` implementation from TraderSpec requirements only, without hydrating source files.

## Inputs

- `foundation/00-traditional-to-cloud-native/specs/components/reference-data/01-functional-requirements.md`
- `foundation/00-traditional-to-cloud-native/specs/components/reference-data/02-non-functional-requirements.md`
- `foundation/00-traditional-to-cloud-native/specs/components/reference-data/03-technical-specification.md`
- `foundation/00-traditional-to-cloud-native/specs/components/reference-data/04-verification-checklist.md`
- `catalog/component-spec.csv` row for `reference-data`

## Generation Constraints

- Language/framework: TypeScript + NestJS.
- Default port: `18085`.
- Implement exact API surface:
  - `GET /stocks`
  - `GET /stocks/{ticker}`
  - `GET /health`
- Preserve payload compatibility for downstream consumers (`trade-service`, Angular UI).
- Do not add auth/authz behavior in this phase.
- Enable CORS for local cross-origin access in pre-ingress mode (default allow all origins; env override allowed).
- Load stock universe from baseline CSV dataset (not a reduced hardcoded symbol seed).

## Deliverables

- Generated component in `codebase/generated-components/reference-data-specfirst`.
- OpenAPI file aligned with implementation behavior.
- Minimal run instructions and verification command list.

## Acceptance Criteria

- All verification checklist items pass.
- Service starts in mixed mode alongside hydrated components (`--overlay-reference-generated`).
- No contract regressions observed in consuming services.
