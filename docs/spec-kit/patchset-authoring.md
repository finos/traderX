---
title: Patch-Set Authoring Workflow
---

# Patch-Set Authoring Workflow

Use this workflow for any new state implementation or state update.

## Why

- Keeps derived state logic as explicit diffs from parent state.
- Reduces brittle shell scripts that write full file payloads.
- Makes LLM changes easier to review and safer to regenerate.

## Standard Flow

1. Pick the parent state from `catalog/state-catalog.json`.
2. Implement the child-state changes (component/root changes as required).
3. Capture/refresh the patch set.
4. Regenerate via `pipeline/generate-state.sh <state-id>`.
5. Run state smoke tests and quality gates.

## Capture Commands

Runtime-root states (`003+`):

```bash
bash pipeline/create-state-patchset.sh <state-id> <parent-state-id>
```

Component-root overlays (state `002` pattern):

```bash
bash pipeline/create-state-patchset.sh <state-id> <parent-state-id> generated/code/components
```

## Apply Command

```bash
bash pipeline/apply-state-patchset.sh <state-id> [target-root]
```

## LLM Implementation Rules

When an LLM implements a state change:

1. Modify files in generated parent output only for that target state.
2. Regenerate patch set immediately using `create-state-patchset.sh`.
3. Replace state hook logic with parent-generation + patch-apply model.
4. Never keep long heredoc file-payload scripts for derived states.
5. Update `specs/<state>/generation/generation-hook.md` with parent, patch path, and refresh command.

## Validation

Run at minimum:

```bash
bash pipeline/speckit/validate-root-spec-kit-gates.sh
bash pipeline/verify-spec-coverage.sh
```

Then run target state smoke tests (and full stack sweep when state impacts shared contracts).
