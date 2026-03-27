# Prompt: Generate Trade-Processor Component (Pure Spec-First)

Use this prompt for the next cutover after `trade-feed`: `trade-processor`.

## Objective

Generate `trade-processor` implementation from TraderSpec requirements, without hydrating source files from root implementation.

## Inputs

- `foundation/00-traditional-to-cloud-native/specs/components/trade-processor/01-functional-requirements.md`
- `foundation/00-traditional-to-cloud-native/specs/components/trade-processor/02-non-functional-requirements.md`
- `foundation/00-traditional-to-cloud-native/specs/components/trade-processor/03-technical-specification.md`
- `foundation/00-traditional-to-cloud-native/specs/components/trade-processor/04-verification-checklist.md`
- `catalog/component-spec.csv` row for `trade-processor`

## Generation Constraints

- Preserve compatibility with trade-service `TradeOrder` topic publishing (`/trades`).
- Preserve persistence model compatibility for `TRADES` and `POSITIONS` data consumed by position-service.
- Preserve account-scoped trade/position publish topic patterns.
- Preserve baseline runtime contract and local env overrides.
- Include pre-ingress CORS behavior for local cross-port operation.
- Do not change dependent service behavior in this step.

## Deliverables

- Generated component in `codebase/generated-components/trade-processor-specfirst`.
- Runtime README, Gradle build files, and boot configuration.
- Overlay startup + smoke test commands for mixed mode.

## Acceptance Criteria

- Verification checklist passes.
- Mixed-mode environment runs with generated `trade-processor` + previously cut-over generated services.
- No regressions in end-to-end trade submission and position update flow.
