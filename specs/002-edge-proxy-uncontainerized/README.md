# Feature Pack 002: Edge Proxy Uncontainerized

Status: Implemented (pending release tag)

This pack defines the first post-baseline state transition from `001-baseline-uncontainerized-parity`.

Primary intent:

- introduce an edge proxy/routing boundary for browser-origin traffic,
- reduce direct browser calls to multiple backend service ports,
- keep runtime uncontainerized for this state,
- preserve functional parity unless explicitly changed.

Implemented artifacts:

- `system/edge-routing.json`
- `system/runtime-topology.md`
- `components/edge-proxy.md`
- `pipeline/generate-state.sh` (state `002` entrypoint)
- `pipeline/generate-edge-proxy-specfirst.sh`
- `scripts/start-state-002-edge-proxy-generated.sh`
