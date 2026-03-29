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

## Implemented Generation Surface

- `bash pipeline/generate-state.sh 002-edge-proxy-uncontainerized`
- `bash pipeline/generate-edge-proxy-specfirst.sh`
- `bash pipeline/apply-state-002-web-overlay.sh`
- `./scripts/start-state-002-edge-proxy-generated.sh`
- `./scripts/test-state-002-edge-proxy.sh`
