# Spec Kit Component: edge-proxy

## Role

Provide one browser-facing endpoint for state `002-edge-proxy-uncontainerized`, routing UI/API/WebSocket traffic to baseline processes.

## Functional Behavior

- Expose `/health` endpoint.
- Forward `/` to Angular upstream (`18093`).
- Forward API prefix routes defined in `system/edge-routing.json`.
- Forward `/socket.io` to trade-feed for pub/sub updates.

## Non-Functional Constraints

- Must remain uncontainerized for this state.
- Must keep backend contracts unchanged.
- Must preserve baseline flow compatibility (F1-F6).

## Generation Source

- Template: `templates/edge-proxy-specfirst/**`
- Generator: `pipeline/generate-edge-proxy-specfirst.sh`
- Routing spec input: `specs/002-edge-proxy-uncontainerized/system/edge-routing.json`
