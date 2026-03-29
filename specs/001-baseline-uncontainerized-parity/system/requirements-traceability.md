# Requirements Traceability

The canonical machine-readable traceability matrix is:

- `specs/001-baseline-uncontainerized-parity/system/requirements-traceability.csv`

It maps:

- requirement id -> user story id -> acceptance criteria id
- flow id -> component id -> contract reference -> verification reference

This matrix is enforced by:

- `pipeline/speckit/validate-speckit-readiness.sh`
- `pipeline/speckit/verify-spec-expressiveness.sh`
