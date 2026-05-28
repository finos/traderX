# State 011 Tilt Local Dev Loop Artifacts

Generated from:

- `specs/011-tilt-kubernetes-dev-loop/**`
- `generated/code/target-generated/kubernetes-runtime/build-plan.json`

State intent:

- preserve state 010 runtime behavior,
- add Tilt-driven local Kubernetes development workflow artifacts.

Artifacts:

- Tiltfile: `tilt/Tiltfile`
- Tilt state metadata: `tilt/tilt-settings.json`
- Copied k8s manifests baseline: `manifests/base`
- Parent image map reference: `upstream-build-plan.json`

Run baseline runtime for this state:

```bash
./scripts/start-state-011-tilt-kubernetes-dev-loop-generated.sh --provider kind
```

Primary endpoints (inherited from state 010 runtime):

- TraderX UI: `http://localhost:8080`
- API Explorer: `http://localhost:8080/api/docs`
- Grafana: `http://localhost:8080/grafana` (admin/admin)
- Prometheus: `http://localhost:8080/prometheus`

Run state smoke tests:

```bash
./scripts/test-state-011-tilt-kubernetes-dev-loop.sh
```

Optional Tilt command flow (requires `tilt`):

```bash
cd generated/code/target-generated/tilt-kubernetes-dev-loop/tilt
tilt up
```
