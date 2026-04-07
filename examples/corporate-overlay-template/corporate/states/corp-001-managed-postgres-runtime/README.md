# corp-001-managed-postgres-runtime

Parent state: `003-containerized-compose-runtime`

## Intent

Demonstrate a corporate policy where state runtime may not use containerized PostgreSQL images.

## Corporate Delta

- containerized Postgres images are blocked by policy
- runtime must use managed endpoint pattern:
  - `managed-postgres-<state-id>.corp.example:5432`
- TLS/cert-based authentication is required

## Example Outputs

- `generated/code/target-generated/corp-overlays/corp-001-managed-postgres-runtime/db.env`
