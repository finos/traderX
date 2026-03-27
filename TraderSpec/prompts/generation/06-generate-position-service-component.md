# Prompt: Generate Position-Service Component (Pure Spec-First)

Use this prompt for the next cutover after `account-service`: `position-service`.

## Objective

Generate `position-service` implementation from TraderSpec requirements, without hydrating source files from root implementation.

## Inputs

- `foundation/00-traditional-to-cloud-native/specs/components/position-service/01-functional-requirements.md`
- `foundation/00-traditional-to-cloud-native/specs/components/position-service/02-non-functional-requirements.md`
- `foundation/00-traditional-to-cloud-native/specs/components/position-service/03-technical-specification.md`
- `foundation/00-traditional-to-cloud-native/specs/components/position-service/04-verification-checklist.md`
- `catalog/component-spec.csv` row for `position-service`

## Generation Constraints

- Preserve endpoint and payload compatibility for `/trades*` and `/positions*`.
- Preserve baseline DB read compatibility with `Trades` and `Positions` tables.
- Preserve health endpoints and baseline runtime contract (`POSITION_SERVICE_PORT` + DB env vars).
- Preserve pre-ingress local CORS compatibility.
- Do not change dependent service behavior during this step.

## Deliverables

- Generated component in `codebase/generated-components/position-service-specfirst`.
- Runtime README and API contract file.
- Overlay startup + smoke test commands for mixed mode.

## Acceptance Criteria

- Verification checklist passes.
- Mixed-mode environment runs with generated `position-service` + generated `database` + previously cut over components.
- No regressions in blotter preload and related trade/position flows.
