# Smoke Tests: 006-tilt-kubernetes-dev-loop

- Primary smoke script: `scripts/test-state-006-tilt-kubernetes-dev-loop.sh`

Document and implement the minimum end-to-end checks required for this state.

Suggested categories:

- Runtime starts cleanly.
- Core API/flow health checks.
- State-specific behavioral checks.

Implemented smoke command:

```bash
./scripts/test-state-006-tilt-kubernetes-dev-loop.sh http://localhost:8080 traderx kind traderx-state-004
```

State-specific checks include:

- Tilt artifact pack generation (`Tiltfile`, `tilt-settings.json`).
- Tiltfile mappings for all runtime images in the inherited state `004` build plan.
