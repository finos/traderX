# Feature Pack 002: Edge Proxy Uncontainerized

Status: Draft

This pack defines the first post-baseline state transition from `001-baseline-uncontainerized-parity`.

Primary intent:

- introduce an edge proxy/routing boundary for browser-origin traffic,
- reduce direct browser calls to multiple backend service ports,
- keep runtime uncontainerized for this state,
- preserve functional parity unless explicitly changed.
