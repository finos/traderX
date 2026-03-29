# 04 Interface Contracts Baseline

## Service Contract Sources

- `account-service/openapi.yaml`
- `trade-service/openapi.yaml`
- `position-service/openapi.yaml`
- `trade-processor/openapi.yaml`
- `reference-data/openapi.yaml`
- `people-service/openapi.yaml`

## Contract Rules

1. Generated implementations must conform to baseline contracts unless a step spec changes them.
2. Contract diffs require compatibility notes and versioning strategy.
3. Functional-track steps may introduce additive endpoints/events with tests.
4. Non-functional-track steps must avoid accidental behavioral contract drift.
