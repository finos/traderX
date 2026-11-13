# Run From Clone

Prerequisites:
- Docker
- kubectl
- jq
- Kind (default) or Minikube

Start baseline runtime (inherited from state 010):

```bash
./scripts/start-state-010-kubernetes-runtime-generated.sh
./scripts/start-state-010-kubernetes-runtime-generated.sh --skip-build
```

Inherited runtime endpoints:
- UI / edge: `http://localhost:8080`
- API explorer (edge): `http://localhost:8080/api/docs`
- Grafana: `http://localhost:8080/grafana`
- Prometheus: `http://localhost:8080/prometheus`

State 013 artifact pack:
- `radius-kubernetes-platform/radius/app.bicep`
- `radius-kubernetes-platform/radius/bicepconfig.json`
- `radius-kubernetes-platform/radius/.rad/rad.yaml`

Optional Radius flow:

```bash
cd radius-kubernetes-platform/radius
rad run app.bicep
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
