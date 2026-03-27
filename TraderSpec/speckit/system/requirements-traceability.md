# Requirements Traceability

The canonical machine-readable traceability matrix is:

- `TraderSpec/speckit/system/requirements-traceability.csv`

It maps:

- requirement id -> user story id -> acceptance criteria id
- flow id -> component id -> contract reference -> verification reference

This matrix is enforced by:

- `TraderSpec/pipeline/speckit/validate-speckit-readiness.sh`
- `TraderSpec/pipeline/speckit/verify-spec-expressiveness.sh`
