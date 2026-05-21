# Research Notes: 003-agentic-harness-foundation

## Problem

Generated codebases were runnable, but lacked consistent agent guidance and explicit contribution boundaries.
This caused confusion about where enhancements should be made.

## Findings

- A minimal, standardized harness in each generated codebase reduces onboarding friction for AI-assisted workflows.
- Contribution policy must be explicit in generated outputs to preserve spec-first governance.
- Duplicating large documentation sets in each generated output increases cognitive load; concise top-level files are preferred.

## Decision

Add exactly three root-level harness files from state `003` onward:

- `AGENTS.md`
- `ARCHITECTURE.md`
- `CONTRIBUTING.md`

Keep generated runbooks (`RUN_FROM_GENERATED.md`, script readmes) as the runtime source of truth.
