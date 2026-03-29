# Smoke Tests: 005-radius-kubernetes-platform

- Primary smoke script: `scripts/test-state-005-radius-kubernetes-platform.sh`

Document and implement the minimum end-to-end checks required for this state.

Suggested categories:

- Runtime starts cleanly.
- Core API/flow health checks.
- State-specific behavioral checks.

Implemented smoke command:

```bash
./scripts/test-state-005-radius-kubernetes-platform.sh http://localhost:8080 traderx kind traderx-state-004
```

State-specific checks include:

- Radius artifact pack generation (`app.bicep`, `bicepconfig.json`, `.rad/rad.yaml`).
- Radius app model declarations for all baseline TraderX runtime components.
