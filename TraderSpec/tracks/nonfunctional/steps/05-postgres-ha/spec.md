# Spec: NF 05 PostgreSQL HA

- `stepId`: `nf-05-postgres-ha`
- `inheritsFrom`: `nf-04-redis-caching|nf-04-distributed-caching`
- `requirementMode`: `nfr-overlay-only`

## NFR Additions

- Database high-availability topology.
- Backup/restore and failover playbooks.
- Connection resiliency and pool tuning.

## Acceptance

- Planned failover preserves availability objectives.
- Backup restore drills succeed within target time.
