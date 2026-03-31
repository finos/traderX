# State 006 Tilt Local Dev Loop Artifacts

Generated from:

- `specs/006-tilt-kubernetes-dev-loop/**`
- `generated/code/target-generated/kubernetes-runtime/build-plan.json`

State intent:

- preserve state 004 runtime behavior,
- add Tilt-driven local Kubernetes development workflow artifacts.

Artifacts:

- Tiltfile: `tilt/Tiltfile`
- Tilt state metadata: `tilt/tilt-settings.json`
- Copied k8s manifests baseline: `manifests/base`
- Parent image map reference: `upstream-build-plan.json`

Run baseline runtime for this state:

```bash
./scripts/start-state-006-tilt-kubernetes-dev-loop-generated.sh --provider kind
```

Run state smoke tests:

```bash
./scripts/test-state-006-tilt-kubernetes-dev-loop.sh
```

Optional Tilt command flow (requires `tilt`):

```bash
cd generated/code/target-generated/tilt-kubernetes-dev-loop/tilt
tilt up
```
