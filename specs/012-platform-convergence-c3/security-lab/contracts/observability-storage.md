# Observability storage, restrictions and Restricted admission

Status: implemented and locally verified for SL-T07f. Targets: Grafana, Prometheus, Loki and Tempo.

- OS-01: Inventory actual data paths in the pinned running images. Preserve Grafana
  /var/lib/grafana, Prometheus /prometheus, Loki /tmp/loki and /loki, Tempo /tmp/tempo
  and /var/tempo. ConfigMap mounts are excluded from filesystem archives.
- OS-02: Acquire the lab experiment lock. For each service, briefly pause its local
  containerd task, archive its data paths outside the repository, record SHA-256,
  request scale-to-zero, and resume the task in finally so shutdown can complete.
  This is a local crash-consistent cutover checkpoint, not zero-loss continuous
  ingestion. Retain backups and phase records; never silently replace them.
- OS-03: Restore to one dedicated 2Gi RWO local PVC per service using a temporary
  non-root, token-free, capability-free, read-only-root helper using an already
  pinned lab image. Reject unsafe archive entries. Match every restored regular
  file's SHA-256 against the archive before exposing the volume to the service.
  Remove the helper after restore. Interrupted migration must preserve evidence and
  require explicit --resume; never overwrite data from a service already resumed.
- OS-04: Run each service with UID/GID/fsGroup 10001, RuntimeDefault, no capabilities
  or escalation, token-free dedicated identity, read-only root, bounded /tmp and
  PVC subPath mounts at the original data paths. Preserve image pins/configuration.
  Use Recreate, at most one replica and actual HTTP readiness/startup probes.
- OS-05: Fail-closed Deployment and protected-Pod admission enforces exact mounts,
  identities, resources and single-server rollout. Test unsafe variants with valid
  positives. Verify runtime process state, token absence, and denied API privileges.
- OS-06: Verify retained dashboard UIDs, a fixed historical Prometheus query, an
  existing Loki marker and an existing Tempo trace after migration. Store only
  hashes/identifiers needed for evidence, not private backup contents in source.
- OS-07: When all nineteen application-namespace workloads conform, enforce
  Restricted v1.35 for every Pod name/identity. Retain the separate constrained
  collector namespace. Test unrelated-name root, escalation, missing seccomp and
  capabilities plus host/privileged variants; compliant dry-run must pass.
- OS-08: Run full trading, log delivery and prior workload checks. Update the console
  so it reports Restricted status accurately. Baseline-history records remain history.

Local PVCs survive Pod replacement, not cluster deletion/host loss. Backup files
and evidence remain local and mutable. Ingestion pauses/gaps and replay during
cutover are possible. These process/storage restrictions do not add OIDC, SQL/NATS
least privilege, network segmentation, operator authentication or runtime protection.
