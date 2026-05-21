# Smoke Coverage: 004 Containerized Compose Runtime

- Primary smoke script: `scripts/test-state-004-containerized.sh`

- Required checks for this state:
  - Containerized ingress/runtime baseline smoke checks pass.
  - Header title renders `TraderX Sample Trading App (004-containerized-compose-runtime)`.
  - `About` tab is visible and routes to an About page with:
    - active state id,
    - generated timestamp,
    - source generated-state branch,
    - prior-state branch list with short feature-summary sentence,
    - API explorer link.
  - `Status` tab is visible and routes to a page showing per-service uptime/health status in containerized runtime.
  - Runtime/start scripts report current generated state id and mismatch guidance before startup.
  - Optional auto-regenerate mode for mismatch handling is validated in smoke workflow.
