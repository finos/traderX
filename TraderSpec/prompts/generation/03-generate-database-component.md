# Prompt: Generate Database Component (Pure Spec-First)

Use this prompt for the next cutover after reference-data: `database`.

## Objective

Generate `database` implementation from TraderSpec requirements, without hydrating source files from root implementation.

## Inputs

- `foundation/00-traditional-to-cloud-native/specs/components/database/01-functional-requirements.md`
- `foundation/00-traditional-to-cloud-native/specs/components/database/02-non-functional-requirements.md`
- `foundation/00-traditional-to-cloud-native/specs/components/database/03-technical-specification.md`
- `foundation/00-traditional-to-cloud-native/specs/components/database/04-verification-checklist.md`
- `catalog/component-spec.csv` row for `database`

## Generation Constraints

- Preserve baseline H2 startup semantics and port contract (`18082`, `18083`, `18084`).
- Preserve baseline schema and seed-data compatibility used by account/position/trade services.
- Keep startup deterministic and fail-fast on initialization errors.
- Do not change API/service-layer behavior in dependent services during this step.

## Deliverables

- Generated component in `codebase/generated-components/database-specfirst`.
- Startup script and initialization SQL artifacts.
- Minimal run instructions and verification command list.

## Acceptance Criteria

- Verification checklist passes.
- Mixed-mode environment runs with generated database + hydrated remaining components.
- No compatibility regressions in account/position/trade-service baseline flows.
