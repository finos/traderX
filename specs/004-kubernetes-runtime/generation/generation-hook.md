# Generation Hook: 004-kubernetes-runtime

- Hook script: `pipeline/generate-state-004-kubernetes-runtime.sh`
- Feature pack: `specs/004-kubernetes-runtime`

This state generates Kubernetes runtime assets from:

- `system/kubernetes-runtime.spec.json`
- `system/nginx-edge.conf`

Hook responsibilities:

1. Reuse generated state `003` assets as component source/build contexts.
2. Generate deterministic Kubernetes manifests into:
   - `generated/code/target-generated/kubernetes-runtime/manifests/base`
3. Generate Kind cluster config into:
   - `generated/code/target-generated/kubernetes-runtime/kind/cluster-config.yaml`
4. Generate image build/load plan into:
   - `generated/code/target-generated/kubernetes-runtime/build-plan.json`
5. Regenerate architecture docs from `system/architecture.model.json`.
