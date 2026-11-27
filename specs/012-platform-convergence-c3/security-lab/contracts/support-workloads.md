# Supporting workload restrictions

Status: implemented and live-verified for SL-T07c. This extends SL-T07a; it does not complete SL-T07b.

Scope: edge-proxy, web-front-end-angular, api-explorer, nats-broker,
blackbox-exporter and otel-collector in traderx-security-lab.

- SW-01: Preserve pinned images and existing application/event routes. Render a
  separate opt-in manifest from the reference, never modify generated snapshots.
- SW-02: Apply UID/GID/fsGroup 10001, RuntimeDefault, zero capabilities, no privilege
  escalation, read-only root and dedicated token-free service accounts. No RBAC
  grants. Read-only ConfigMap mounts retain their exact source names/paths.
- SW-03: Allow a 128Mi /tmp emptyDir. Nginx alone additionally gets 16Mi /run and
  32Mi /var/cache/nginx. Bypass its configuration-mutating image entrypoint by
  running nginx directly. Keep its packaged nginx.conf; ignore the expected
  non-root `user` directive warning. API docs listen on unprivileged port 8080
  using a dedicated ConfigMap; update only their Service targetPort accordingly.
- SW-04: Requests 10m CPU/32Mi memory; limits 1 CPU/256Mi for Nginx and 1 CPU/512Mi
  for NATS/exporter/collector. These are lab compatibility bounds. Use HTTP
  readiness and sequential no-surge rollout, with bounded waits and scoped rollback.
- SW-05: Extend fail-closed named-Deployment admission to these six workloads,
  enforcing identities, restrictions, resources, exact mount sources and writable
  allowances. Test schema-valid negative variants and accept no schema failure as
  proof of policy enforcement.
- SW-06: Extend protection to directly submitted Pods matching a protected app
  label OR protected service-account identity for both workload groups. Renaming
  both is outside this incremental boundary; namespace-wide admission remains
  open. No extra privilege for ephemeral debug containers is part of this slice.
- SW-07: Inspect six live processes, kernel restrictions, actual mounts/resources,
  token absence and identity permissions. Test tmp/root writes in the edge image.
  Rerun business-workload checks and the complete trading smoke after rollout.
  Retain structured evidence and expose this bounded check through the console.

NATS remains unauthenticated until SL-T10; non-root execution is not subject
permission enforcement. Gateway WAF/TLS and operator route segregation remain open.
Database, Grafana, Prometheus, Loki, Tempo and the host-log collector are unchanged.
No restart or migration of their storage is part of this slice.
