# Prompt: Generate People-Service Component (Pure Spec-First)

Use this prompt for the next cutover after `database`: `people-service`.

## Objective

Generate `people-service` implementation from TraderSpec requirements, without hydrating source files from root implementation.

## Inputs

- `foundation/00-traditional-to-cloud-native/specs/components/people-service/01-functional-requirements.md`
- `foundation/00-traditional-to-cloud-native/specs/components/people-service/02-non-functional-requirements.md`
- `foundation/00-traditional-to-cloud-native/specs/components/people-service/03-technical-specification.md`
- `foundation/00-traditional-to-cloud-native/specs/components/people-service/04-verification-checklist.md`
- `catalog/component-spec.csv` row for `people-service`

## Generation Constraints

- Preserve baseline endpoint paths and query parameter compatibility under `/People/*`.
- Preserve response payload compatibility for account-service and Angular user search flows.
- Preserve pre-ingress CORS compatibility for cross-origin localhost browser calls.
- Keep runtime contract explicit (`net9.0`, `PEOPLE_SERVICE_PORT`, `CORS_ALLOWED_ORIGINS`).
- Do not change dependent service behavior in this step.

## Deliverables

- Generated component in `codebase/generated-components/people-service-specfirst`.
- Runtime README and API contract file (`openapi.yaml`).
- Verification command set and smoke test script usage.

## Acceptance Criteria

- Verification checklist passes.
- Mixed-mode environment runs with generated `people-service` + generated `reference-data` + generated `database`.
- No regressions in baseline user lookup and account-user validation flows.
