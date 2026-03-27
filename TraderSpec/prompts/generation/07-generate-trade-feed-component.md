# Prompt: Generate Trade-Feed Component (Pure Spec-First)

Use this prompt for the next cutover after `position-service`: `trade-feed`.

## Objective

Generate `trade-feed` implementation from TraderSpec requirements, without hydrating source files from root implementation.

## Inputs

- `foundation/00-traditional-to-cloud-native/specs/components/trade-feed/01-functional-requirements.md`
- `foundation/00-traditional-to-cloud-native/specs/components/trade-feed/02-non-functional-requirements.md`
- `foundation/00-traditional-to-cloud-native/specs/components/trade-feed/03-technical-specification.md`
- `foundation/00-traditional-to-cloud-native/specs/components/trade-feed/04-verification-checklist.md`
- `catalog/component-spec.csv` row for `trade-feed`

## Generation Constraints

- Preserve socket command compatibility (`subscribe`, `publish`, and unsubscribe variants).
- Preserve message envelope shape and wildcard inspector topic behavior.
- Preserve runtime compatibility with Angular UI, trade-service, and trade-processor publishers/subscribers.
- Preserve baseline runtime contract (`TRADE_FEED_PORT`, pre-ingress CORS behavior).
- Do not change dependent service behavior in this step.

## Deliverables

- Generated component in `codebase/generated-components/trade-feed-specfirst`.
- Runtime README and package manifest/start command.
- Overlay startup + smoke test commands for mixed mode.

## Acceptance Criteria

- Verification checklist passes.
- Mixed-mode environment runs with generated `trade-feed` + previously cut-over generated services.
- No regressions in live trade/position update propagation paths.
