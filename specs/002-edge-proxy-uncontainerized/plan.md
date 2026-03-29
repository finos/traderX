# Implementation Plan: 002 Edge Proxy Uncontainerized

## Scope

- Add edge proxy/routing component behavior and runtime wiring.
- Keep backend contracts stable.
- Keep process-based (non-containerized) startup flow.

## Technical Approach

1. Define target edge routes and backend mappings from baseline flow requirements.
2. Update runtime scripts to include edge component in deterministic startup order.
3. Update UI endpoint configuration to use edge endpoint.
4. Preserve service API contracts and validate conformance.
5. Regenerate impacted components and runtime artifacts from this pack.

## Validation

- Component conformance packs for impacted components.
- End-to-end smoke checks for F1-F6 through edge routing.
- Full parity validation against intended state constraints.
