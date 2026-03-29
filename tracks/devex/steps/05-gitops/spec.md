# Spec: DevEx 05 GitOps

- `stepId`: `devex-05-gitops`
- `inheritsFrom`: `devex-04-kubernetes|devex-04-radius`
- `requirementMode`: `nfr-overlay-only`

## NFR Additions

- Declarative promotion flow via Git changes.
- Environment drift detection and reconciliation.
- Deployment auditability and approval gates.

## Acceptance

- Git change drives deployment reconciliation.
- Drift between desired and actual state is detectable.
