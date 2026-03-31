# Run From Clone

Prerequisites:
- Docker
- kubectl
- jq
- Kind (default) or Minikube

Start baseline runtime (inherited from state 004):

```bash
./scripts/start-state-004-kubernetes-generated.sh
```

State 005 artifact pack:
- `radius-kubernetes-platform/radius/app.bicep`
- `radius-kubernetes-platform/radius/bicepconfig.json`
- `radius-kubernetes-platform/radius/.rad/rad.yaml`

Optional Radius flow:

```bash
cd radius-kubernetes-platform/radius
rad run app.bicep
```
