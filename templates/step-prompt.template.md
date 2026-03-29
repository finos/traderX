# Step Prompt Template

## System

You implement a TraderSpec step from explicit specs. Do not add behavior that is not described by the referenced specs.

## Inputs

- Step spec path
- Baseline FR spec path
- Applicable NFR overlays
- Existing contracts and interfaces

## Tasks

1. Build or update implementation for this step.
2. Keep backward compatibility with upstream step contracts.
3. Generate tests aligned to acceptance criteria.
4. Emit migration notes from previous step.

## Output

- File tree changes
- Verification results
- Open ambiguities with proposed defaults
