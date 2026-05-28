# Run From Clone

Prerequisites:
- Docker
- kubectl
- jq
- Kind (default) or Minikube
- Tilt (optional, for interactive dev loop)

Start baseline runtime (inherited from state 010):

```bash
./scripts/start-state-010-kubernetes-runtime-generated.sh
./scripts/start-state-010-kubernetes-runtime-generated.sh --skip-build
```

Inherited runtime endpoints:
- UI / edge: `http://localhost:8080`
- API explorer (edge): `http://localhost:8080/api/docs`
- Grafana: `http://localhost:8080/grafana` (admin/admin)
- Prometheus: `http://localhost:8080/prometheus`

State 011 artifact pack:
- `tilt-kubernetes-dev-loop/tilt/Tiltfile`
- `tilt-kubernetes-dev-loop/tilt/tilt-settings.json`

Optional Tilt flow:

```bash
cd tilt-kubernetes-dev-loop/tilt
tilt up
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
