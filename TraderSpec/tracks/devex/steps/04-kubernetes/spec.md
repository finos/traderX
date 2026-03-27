# Spec: DevEx 04 Kubernetes Deployment

- `stepId`: `devex-04-kubernetes`
- `inheritsFrom`: `devex-03-tilt-dev`
- `requirementMode`: `nfr-overlay-only`

## NFR Additions

- Kubernetes deployment manifests for all core modules.
- Namespace and configuration management discipline.
- Health/readiness and rollout observability.

## Acceptance

- Core services deploy and become ready in cluster.
- Rollout and rollback operations are documented and testable.
