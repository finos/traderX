# Prompt: Generate Account-Service Component (Pure Spec-First)

Use this prompt for the next cutover after `people-service`: `account-service`.

## Objective

Generate `account-service` implementation from TraderSpec requirements, without hydrating source files from root implementation.

## Inputs

- `foundation/00-traditional-to-cloud-native/specs/components/account-service/01-functional-requirements.md`
- `foundation/00-traditional-to-cloud-native/specs/components/account-service/02-non-functional-requirements.md`
- `foundation/00-traditional-to-cloud-native/specs/components/account-service/03-technical-specification.md`
- `foundation/00-traditional-to-cloud-native/specs/components/account-service/04-verification-checklist.md`
- `catalog/component-spec.csv` row for `account-service`

## Generation Constraints

- Preserve baseline endpoint paths and payload compatibility for `/account*` and `/accountuser*`.
- Preserve database integration semantics with baseline H2 schema (`Accounts`, `AccountUsers`).
- Preserve people-service validation behavior for account-user creation.
- Preserve baseline runtime contract (`ACCOUNT_SERVICE_PORT`, DB env vars, people-service URL/host).
- Do not change dependent service behavior during this step.

## Deliverables

- Generated component in `codebase/generated-components/account-service-specfirst`.
- Runtime README and API contract file.
- Verification command set and smoke test script for mixed mode.

## Acceptance Criteria

- Verification checklist passes.
- Mixed-mode environment runs with generated `account-service` + generated `people-service` + generated `database` + generated `reference-data`.
- No regressions in account lookup, account-user mapping, and UI account flows.
