# Log collector isolation and namespace Baseline admission

Status: implemented and live-verified for SL-T07e; full Restricted admission remains SL-T07b.

- CB-01: Move the pinned Vector DaemonSet (named promtail in C3) from
  traderx-security-lab to traderx-security-infra. Preserve its application-namespace
  log filter and send to Loki using its qualified cross-namespace Service name.
  Do not restart Grafana, Prometheus, Loki or Tempo; their current histories live
  in writable container layers and need separate storage migrations.
- CB-02: The collector has a documented root/read-only-host-log/API-token exception.
  Drop all capabilities, deny privilege escalation, use RuntimeDefault and a
  read-only root. Allow only /var/log/pods (read-only hostPath), the fixed config,
  bounded 64Mi /run/vector and a projected 1-hour service-account token with CA and
  namespace. Automatic token mounting stays disabled. No host namespaces/sockets.
- CB-03: Give its dedicated identity get/list/watch on pods/nodes/namespaces only.
  Verify metadata access succeeds while secrets and mutations fail. Remove the old
  application-namespace collector's binding after successful cutover. The filter is
  collection scope, not a kernel confidentiality boundary: a compromised root
  collector could read other files under its mounted host log directory.
  Pod API reads include Pod specifications; this is not a metadata-only API view.
- CB-04: Fail-closed admission for every Pod/debug update in the infrastructure
  namespace admits only this pinned collector identity/configuration. Enforce its
  exact host path, read-only mount, token projection, resource limits and container
  count. Reject unrelated/renamed Pods and broadened paths/privileges. Protect the
  named DaemonSet too. Infrastructure is not a general privileged playground.
- CB-05: Prove a fresh application log marker reaches Loki before stopping the old
  collector and another marker reaches Loki after it is removed. Preserve its
  checkpoint directory in a private archive before cutover. The new collector
  starts with fresh offsets, so duplicate log replay is possible and disclosed.
  Existing Loki history remains in the untouched running Loki Pod.
- CB-06: Only after removal of the hostPath collector, enforce Kubernetes Baseline
  v1.35 on the entire application namespace. Prove a compliant Pod dry-run passes
  and unrelated-name/default-identity privileged, hostPath, host namespace and
  unconfined-seccomp Pods are denied by Pod Security Admission. This is not
  Restricted: root, writable roots and automatic tokens are not generally denied
  by Baseline. Existing stronger named-workload policies remain active.
- CB-07: All workload verifiers and trading smoke must pass after cutover. Extend
  smoke readiness to look for the relocated collector; preserve original states'
  default namespace behavior. Do not weaken smoke validation to skip the collector.

Design references reviewed 2026-11-22:
[Kubernetes namespace admission](https://kubernetes.io/docs/tasks/configure-pod-container/enforce-standards-namespace-labels/)
and [Vector Kubernetes logs](https://vector.dev/docs/reference/configuration/sources/kubernetes_logs/).
