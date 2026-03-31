# State 005 Radius Platform Artifacts

Generated from:

- `specs/005-radius-kubernetes-platform/**`
- `generated/code/target-generated/kubernetes-runtime/build-plan.json`

State intent:

- preserve state 004 runtime behavior,
- add Radius app/resource definitions as the primary platform abstraction artifacts.

Artifacts:

- Radius app model: `radius/app.bicep`
- Radius workspace config: `radius/.rad/rad.yaml`
- Bicep extension config: `radius/bicepconfig.json`
- Parent image map reference: `upstream-build-plan.json`

Run baseline runtime for this state:

```bash
./scripts/start-state-005-radius-kubernetes-platform-generated.sh --provider kind
```

Run state smoke tests:

```bash
./scripts/test-state-005-radius-kubernetes-platform.sh
```

Optional Radius command flow (requires `rad`):

```bash
cd generated/code/target-generated/radius-kubernetes-platform/radius
rad run app.bicep
```
