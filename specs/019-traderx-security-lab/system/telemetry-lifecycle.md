# Fresh telemetry storage and cumulative runtime candidate

This increment adds fresh Grafana, Prometheus, Loki and Tempo storage, an isolated log collector, and cumulative contributor `start`, `stop` and `test` commands. It preserves the distinction between a working runtime candidate and the complete hardened State 019: identity/broker cutover, WAF/network integration, image trust and runtime enforcement remain separately gated.

## Fresh storage without a privileged initializer

`telemetry_lifecycle.py` creates four owned PVCs and a dedicated `lab-telemetry-init` service account with no automatically mounted API token. Each bounded initializer Job runs as UID/GID 10001 with RuntimeDefault seccomp, dropped capabilities, no privilege escalation and a read-only root filesystem. Only its reviewed PVC is writable. The image is pinned to the existing Grafana image digest, which supplies the shell used to create the reviewed data directories.

An empty volume receives the required subdirectories and an owner/layout binding marker. A volume with unknown contents, a mismatched marker or wrongly owned/unwritable directories is refused; initialization never recursively changes ownership, deletes files or restores a backup. An interrupted initializer that left data without its binding requires explicit inspection. Completed Jobs are retained. Existing workload/Job state with a missing PVC is rejected rather than silently creating a replacement database or telemetry store.

The first live attempt demonstrated why the initializer needs its own identity: workload admission rejected a Job using the Loki service account without the Loki application shape. The unused, owned Job was removed after confirming no Pod had run and its PVC was still unbound. The fix introduced the dedicated tokenless initializer identity; it did not weaken the workload policy.

## Collector exception and stop behavior

The candidate's log collector runs in `traderx-security-infra-019`, separate from the Restricted application namespace. Its configuration selects only the candidate application namespace and sends logs to that namespace's Loki Service. Its cluster role grants read-only discovery of Pods, Nodes and Namespaces; it does not grant access to Secrets or workload mutation.

The infrastructure namespace uses a deliberate privileged Pod Security exception because the collector requires root access to a read-only host-log mount. Two namespace-scoped admission policies constrain the pinned executable/image, mount paths, capabilities, token projection, resource limits and container count. This is a controlled exception, not a claim that every component is unprivileged.

Stop disables the owned DaemonSet using a node selector verified not to match any node, waits for its Pods to disappear, then scales telemetry deployments down. PVCs, Jobs, identities and configuration remain intact. Collector checkpoints currently use `emptyDir`: restart can replay logs, so the campaign makes no exactly-once or duplicate-free delivery claim. Loki's stored log copy is on its PVC. This persistence proof does not establish tamper-resistant audit storage: network and operator-access integration remain separate security gates.

## Effect-based verification

`verify_telemetry_lifecycle.py` uses temporary loopback-only port forwards and verifies:

- A unique log emitted by a Restricted application-namespace probe reaches Loki through the isolated collector.
- A synthetic OTLP trace submitted to the OTEL collector appears in Tempo.
- Prometheus self-scraping records a healthy metric at a fixed timestamp.
- A newly created Grafana dashboard exists independently of provisioned dashboards.
- After stopping and restarting the telemetry components, all four records remain available, the four PVC UIDs are unchanged, and the four telemetry Deployment Pod UIDs have changed.
- Collector RBAC permits the reviewed discovery operations and denies Secret access and workload changes. Server-side dry runs reject a writable host mount, a host-root mount and an extended token lifetime.

The trace fixture follows the [OTLP JSON encoding contract](https://opentelemetry.io/docs/specs/otlp/): hexadecimal trace/span IDs, numeric enums and decimal nanosecond timestamps. A successful receiver response alone is insufficient; the verifier reads the trace back from Tempo.

The campaign exercises graceful shutdown and restart, not disk loss, forced termination or a managed-cloud recovery guarantee. Grafana retains the reference demo login, and the storage endpoints are internal ClusterIP Services; operator authentication remains pending.

## Cumulative contributor commands

`state_lifecycle.py` composes database, telemetry and trading lifecycle functions. It includes all twelve admission-policy families from the offline control candidate, scoped to the separate candidate namespaces. It requires an explicit kubeconfig, context, previously recorded cluster UID and verified private credential store. It never starts another cluster or adopts the earlier prototype automatically.

```bash
python scripts/security-lab/state_lifecycle.py start \
  --runtime-dir /private/tmp/traderx-security-runtime \
  --store /private/tmp/traderx-security-runtime/state019-kubernetes/identities \
  --kubeconfig /private/tmp/traderx-security-runtime/kubeconfig \
  --context kind-traderx-security-lab \
  --cluster-uid <previously-recorded-cluster-uid> \
  --namespace traderx-security-lab-019
```

Use the same arguments with `test --output <new-private-evidence-file>` or `stop`. Test rechecks telemetry persistence and trading outcomes; stop preserves storage and credentials. A failed start/test attempts shutdown of both telemetry and trading components, even if one shutdown reports an error. Inspect retained resources if shutdown is incomplete.

The shared operation lock prevents overlapping lab operations. Live startup checks host pressure and Docker headroom before each workload. The lightweight browser lab must be stopped first. Citrix and other user applications are left untouched; elevated host pressure blocks live work. Offline generation and unit tests remain available without a cluster.

These commands are contributor runtime entrypoints. Clean-clone cumulative generation, guided portal wiring, full security acceptance and generated-state publication remain separate tasks. Do not apply the entire offline control bundle directly as a substitute for this ordered lifecycle.

The [24 November cumulative evidence](../evidence/2026-11-24-cumulative-telemetry.json) records the standalone persistence campaign and the combined nineteen-Deployment test. In the combined campaign, business services remained running through telemetry recreation and trading checks passed afterward. Sampled host pressure remained normal with Citrix running; the recorded full-candidate Docker working set was approximately 5.0 GB. This is a point observation, not a peak-memory benchmark or capacity guarantee.
