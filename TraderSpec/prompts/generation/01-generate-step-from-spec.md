# Prompt: Generate Step From Spec

## Inputs

- Step spec file
- Baseline FR spec
- Active NFR overlays
- Applicable contracts

## Tasks

1. Implement only behaviors declared in specs.
2. Preserve compatibility with upstream step contracts.
3. Add tests mapped to acceptance criteria.
4. Emit migration notes and rollback guidance.
5. In pre-ingress baseline states, include explicit CORS configuration for browser-facing APIs when services run on separate localhost ports.
