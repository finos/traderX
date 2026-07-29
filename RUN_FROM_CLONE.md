# Run From Clone

Prerequisites:
- Docker
- kubectl
- jq
- Kind (default) or Minikube
- Tilt (optional, for interactive dev loop)

Start convergence runtime:

```bash
./scripts/start-state-012-platform-convergence-c3-generated.sh
./scripts/start-state-012-platform-convergence-c3-generated.sh --skip-build
```

Inherited runtime endpoints:
- UI / edge: `http://localhost:8080`
- API explorer (edge): `http://localhost:8080/api/docs`
- Grafana: `http://localhost:8080/grafana`
- Prometheus: `http://localhost:8080/prometheus`

State 012 artifact pack:
- `tilt-kubernetes-dev-loop/tilt/Tiltfile`
- `tilt-kubernetes-dev-loop/tilt/tilt-settings.json`

Status / stop:

```bash
./scripts/status-state-012-platform-convergence-c3-generated.sh
./scripts/stop-state-012-platform-convergence-c3-generated.sh
```

## Stable Entrypoints

Use root wrappers for this generated branch:

```bash
./start-env.sh   # start this state runtime
./status-env.sh  # runtime health/status
./stop-env.sh    # stop runtime
./test-env.sh    # state smoke/validation
```

Wrappers intentionally delegate to numbered state scripts to maximize reuse while keeping clone-first commands stable.
