# 09 Regeneration Strategy (Spec-First)

## Baseline vs Parity

- **Baseline (spec baseline)**: requirements and technical constraints that define intended behavior.
- **Parity snapshot**: copied current implementation used only as a reference oracle.

Parity is not the target model. The target model is generated from baseline + step specs.

## Regeneration Pipeline

1. Validate specification completeness.
2. Generate component scaffolds from `catalog/component-spec.csv`.
3. Generate API-facing stubs from service OpenAPI contracts.
4. Generate UI service endpoints/config from service endpoint spec.
5. Run requirement-trace validation and compatibility checks.
6. Compare generated behavior to parity snapshot and close gaps.

## Done Criteria for “Generated, Not Copied”

- No direct source copy needed for core runtime modules.
- Every generated artifact maps to explicit requirement/spec input.
- Diff against parity shows only intentional differences.
