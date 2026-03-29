# Spec: NF 02 OAuth2

- `stepId`: `nf-02-oauth2`
- `inheritsFrom`: `nf-01-basic-auth`
- `requirementMode`: `nfr-overlay-only`

## NFR Additions

- OAuth2/OIDC integration and token validation.
- Token lifecycle and revocation handling.
- Identity provider integration boundaries.

## Acceptance

- Valid tokens authorize protected flows.
- Invalid/expired tokens are consistently rejected.
