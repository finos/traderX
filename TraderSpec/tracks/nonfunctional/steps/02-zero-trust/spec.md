# Spec: NF 02 Zero Trust

- `stepId`: `nf-02-zero-trust`
- `inheritsFrom`: `nf-01-basic-auth`
- `requirementMode`: `nfr-overlay-only`

## NFR Additions

- Service identity enforcement and mTLS posture.
- Default-deny network policy model.
- Least-privilege service communication rules.

## Acceptance

- Unapproved inter-service traffic is denied.
- Approved service paths operate with identity enforcement.
