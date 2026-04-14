# Smoke Coverage: 002 Edge Proxy Uncontainerized

- Primary smoke script: `scripts/test-state-002-edge-proxy.sh`

- Required checks for this state:
  - Baseline edge proxy health and core proxied endpoint checks continue to pass.
  - Header title renders `TraderX Sample Trading App (002-edge-proxy-uncontainerized)`.
  - `About` tab is visible and routes to an About page with:
    - active state id,
    - generated timestamp,
    - source generated-state branch,
    - prior-state branch list with short feature-summary sentence,
    - API explorer link.
  - `Status` tab is visible and routes to a page showing per-service uptime/health status via edge-accessible health/status sources.
  - Startup runtime scripts report current generated state id and mismatch guidance before startup.
  - Optional auto-regenerate mode for mismatch handling is validated in smoke workflow.
