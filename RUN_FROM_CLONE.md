# Run From Clone

Prerequisites:
- Docker
- kubectl
- jq
- Kind (default) or Minikube
- Tilt (optional, for interactive dev loop)

Start baseline runtime (inherited from state 004):

```bash
./scripts/start-state-004-kubernetes-generated.sh
```

State 006 artifact pack:
- `tilt-kubernetes-dev-loop/tilt/Tiltfile`
- `tilt-kubernetes-dev-loop/tilt/tilt-settings.json`

Optional Tilt flow:

```bash
cd tilt-kubernetes-dev-loop/tilt
tilt up
```
