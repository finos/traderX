# Prompt: Generate Trade-Service Component (Pure Spec-First)

Use this prompt for the next cutover after `trade-processor`: `trade-service`.

## Objective

Generate `trade-service` implementation from TraderSpec requirements, without hydrating source files from root implementation.

## Inputs

- `foundation/00-traditional-to-cloud-native/specs/components/trade-service/01-functional-requirements.md`
- `foundation/00-traditional-to-cloud-native/specs/components/trade-service/02-non-functional-requirements.md`
- `foundation/00-traditional-to-cloud-native/specs/components/trade-service/03-technical-specification.md`
- `foundation/00-traditional-to-cloud-native/specs/components/trade-service/04-verification-checklist.md`
- `catalog/component-spec.csv` row for `trade-service`

## Generation Constraints

- Preserve endpoint and payload compatibility for Angular UI (`POST /trade/`).
- Preserve account + ticker validation behavior with deterministic `404` failures.
- Preserve publish behavior to trade-feed topic `/trades`.
- Preserve baseline runtime contract and local env overrides.
- Include pre-ingress CORS behavior for local cross-port operation.
- Do not change dependent service behavior in this step.

## Deliverables

- Generated component in `codebase/generated-components/trade-service-specfirst`.
- Runtime README, Gradle build files, and boot configuration.
- Overlay startup + smoke test commands for mixed mode.

## Acceptance Criteria

- Verification checklist passes.
- Mixed-mode environment runs with generated `trade-service` + previously cut-over generated services.
- No regressions in GUI trade submission and downstream processing flow.
