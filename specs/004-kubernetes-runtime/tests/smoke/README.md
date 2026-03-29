# Smoke Tests: 004-kubernetes-runtime

- Primary smoke script: `scripts/test-state-004-kubernetes-runtime.sh`

Minimum checks for this state:

- Kubernetes deployment availability in namespace `traderx`.
- Edge health and UI entrypoint through `http://localhost:8080`.
- Baseline API compatibility through edge-prefixed routes:
  - reference-data
  - account-service
  - people-service
  - position-service
  - trade-service (including unknown ticker/account checks).
