# Why TraderX Was Reworked Around SpecKit

## Problem We Needed to Solve

The old model was implementation-first. Behavior lived mainly in code and scripts, which made it harder to:

- regenerate the platform from requirements alone,
- compare intended behavior vs generated behavior,
- manage multiple app states without drift.

## What SpecKit Changes

TraderX now treats specs as primary and implementation as derived.

- Source-of-truth requirements and governance live in:
  - `.specify/**`
  - `specs/**`
- Generation pipelines consume those artifacts and synthesize runnable code.
- Conformance and parity checks verify generated output still matches required behavior.

## What A Developer Needs To Know

1. Start from the baseline feature pack:
   - `specs/001-baseline-uncontainerized-parity`
2. Read the key system docs first:
   - `system/system-context.md`
   - `system/system-requirements.md`
   - `system/end-to-end-flows.md`
3. Regenerate components with `pipeline/generate-*-specfirst.sh`.
4. Run the baseline with `scripts/start-base-uncontainerized-generated.sh`.
5. Validate with conformance/parity gates in `pipeline/speckit/**`.

## Why This Is Better For Multi-State Evolution

State changes become explicit requirement deltas instead of ad-hoc code edits.

- each state is spec-first,
- each generated output is traceable,
- each transition can be reviewed, tested, and replayed.
