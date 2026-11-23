# Business workload restrictions

Status: implemented and live-verified (SL-T07a). Scope: account-service, position-service,
trade-service, trade-processor, order-matcher, people-service, reference-data and
price-publisher in the existing isolated lab. This is a staged profile, not full M3.

## Requirements

- WL-01: Render deterministically from the pinned reference manifests without changing
  reference.json or the generated snapshot. Reject missing, duplicate or unexpected
  target container layouts. Preserve service contracts and image digests.
- WL-02: Each service gets a dedicated `lab-<service>` ServiceAccount with no RBAC
  grants and automountServiceAccountToken=false on account and pod.
- WL-03: Explicit UID/GID 10001, runAsNonRoot, RuntimeDefault seccomp, no privilege
  escalation, no capabilities, read-only root; only /tmp is writable (128Mi
  size-limited emptyDir). No host namespaces, hostPath, additional containers,
  projected tokens or custom security profiles in this slice.
- WL-04: Requests 25m CPU/64Mi memory; limits 2 CPU/512Mi memory for Node/.NET
  services and 2 CPU/768Mi for Java services. These are lab compatibility bounds,
  not measured production sizing. Roll out sequentially to fit the 6GB host, with
  maxSurge=0/maxUnavailable=1 and actual application HTTP readiness probes. Each
  service may briefly be unavailable; wait for health before updating the next.
- WL-05: Fail-closed ValidatingAdmissionPolicy protects CREATE/UPDATE of these
  eight exact Deployment names in this exact namespace. Require the complete
  rendered pod configuration, including resources and mounts. Negative dry-run
  updates must fail with the named policy; the unchanged Deployment must pass.
- WL-06: Verify running pods use the expected configuration and kernel process
  UID/capability/no-new-privilege/seccomp state. A bounded account-service probe
  must write/remove a /tmp file, fail a root-filesystem write with EROFS, and find
  no service-account token. Impersonated service accounts cannot read secrets or
  create deployments. Full inherited trading smoke must pass after rollout.
- WL-07: Store timestamped results and hashes outside source control; retain only
  sanitized summary evidence in the spec. Rollback removes only this policy
  binding/policy then reapplies only the eight reference Deployments. Never
  redeploy the ephemeral database as part of applying or rolling back this slice.

## Boundaries and limitations

Policy scope is deliberately eight Deployment names, not namespace-wide Restricted
admission. An administrator can create a differently named workload or change
ReplicaSets/Pods directly; that is not a protected deployment-author boundary yet.
Application identities receive no such Kubernetes privileges or tokens. Broad
namespace admission and infrastructure separation remain SL-T07b. No assertion
that runtime process restrictions prevent misuse of legitimate DB/NATS access.

M2 CNI and admission compatibility are verified. This slice depends only on that
verified subset; integrated gateway and runtime-hook compatibility remain open.

Design references (reviewed 2026-11-22):
[Kubernetes Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
and [ValidatingAdmissionPolicy](https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/).
Actual acceptance is tested against the pinned Kubernetes 1.35.0 node.
