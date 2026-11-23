# PostgreSQL storage and workload boundary

Status: implemented and live-verified for SL-T07d. This is storage/process hardening, not scoped SQL
roles (SL-T09). Preserve the current synthetic dataset and original image pin.

- DBW-01: Before replacing the reference emptyDir Pod, acquire the lab experiment
  lock, stop all eight business services, wait for their Pods to terminate, record
  original replica counts, and create a private PostgreSQL custom-format backup.
  Capture exact table row counts and ordered-content fingerprints; ensure they
  are unchanged across the backup. Never print data rows or backup credentials.
- DBW-02: Use a dedicated 2Gi ReadWriteOnce PVC on the observed local-path storage
  class. Store PGDATA in its pgdata subdirectory; use UID/GID/fsGroup 70 (the pinned
  image's postgres user), token-free lab-database identity, RuntimeDefault, no
  privilege escalation/capabilities and a read-only root. Allow only bounded /tmp
  and socket emptyDirs, the PVC and a read-only bootstrap ConfigMap. Bootstrap
  with no seed SQL, then restore the verified backup in one transaction.
- DBW-03: Do not restore business replicas until every table fingerprint matches.
  Keep the backup and phase record private outside the worktree. A failed migration
  leaves writers stopped, reports its phase and supports explicit --resume. Never
  silently fall back to an empty database or overwrite the backup on resume.
- DBW-04: Prove storage durability by restarting the migrated database Pod while
  writers remain stopped, then checking all fingerprints again. Use Recreate
  strategy so only one server owns this local database volume at a time.
- DBW-05: Enforce the named Deployment and protected database Pod label/identity
  through fail-closed admission. Require the precise identity, read-only root,
  resource bounds, PGDATA, volume source/path and bootstrap configuration. Require
  Recreate strategy and at most one database replica. Verify
  schema-valid unsafe mutations are denied and a compliant Pod dry-run passes.
- DBW-06: Verify process UID/capabilities/seccomp, token absence and RBAC denials,
  plus an actual root write rejection and /tmp success. Full business/support
  verifiers and trading smoke must pass after original replicas return.

The local PVC survives Pod replacement, not cluster deletion or host loss. This
is a local recovery exercise, not production backup/HA. The original superuser
application SQL credentials remain until SL-T09, and namespace-wide admission is
still pending. Do not rerun the unrestricted reference starter over this profile.
Rollback must use a preserved backup and a separately planned data restore;
simply reverting manifests would restore emptyDir storage and risk data loss.
