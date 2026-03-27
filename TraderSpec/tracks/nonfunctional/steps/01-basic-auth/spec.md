# Spec: NF 01 Basic Auth

- `stepId`: `nf-01-basic-auth`
- `inheritsFrom`: `base-00-traditional`
- `requirementMode`: `nfr-overlay-only`

## NFR Additions

- Basic authentication and endpoint protection baseline.
- Credential/config handling controls.
- Unauthorized access handling and auditing.

## Acceptance

- Protected endpoints reject unauthenticated requests.
- Auth flow is covered by smoke tests.
