# Business workload verification — 22 November 2026

SL-T07a is complete. Eight reviewed business services run as UID/GID 10001,
with zero effective/bounding capabilities, no-new-privileges, seccomp filtering,
read-only root, dedicated service accounts and no mounted API tokens. Actual Pod
resources and the bounded /tmp volume were verified. Full SL-T07 remains open.

## Results

- Browser run `687b360b-0c8b-4e49-a7d2-5f0cce529a14` passed; its downloaded
  artifact hash was checked against the downloaded payload.
- Eight live processes were inspected via the node CRI and /proc, including
  distroless images without adding debug containers.
- All eight identities were denied secret reads and Deployment creation using
  impersonation with normal service-account and authenticated groups.
- Eleven unsafe updates were denied by the named policy in server dry-run:
  root, writable root, token mount, added capability, privileged mode, unconfined
  seccomp, host networking, missing resources, host mount, sidecar and default
  service account. No unsafe Pod was launched.
- The account-service /tmp write/remove succeeded; root write failed specifically
  with `Read-only file system`.
- The full inherited State 012/011/010 trading smoke passed after rollout,
  including processing/settlement, APIs and observability.

## Corrections retained in evidence

The first rollout inherited missing application readiness probes, allowing several
emulated JVMs to boot together. Database liveness checks timed out, causing two
restarts; its existing Pod/emptyDir was preserved. One worker restarted during this
disruption. The first smoke failed during rollout. The canonical profile now adds
HTTP readiness and sequential rollout without surge replicas. The corrected rollout
and final smoke passed; no further database restart was observed during that rollout.

The first console privileged-mode negative test was schema-invalid and rejected
before the policy. That failed run remains in history. The fixture was corrected;
the repeat attributes all eleven denials to the named admission policy.

## Limits and artifacts

Only eight exact Deployment names are admission-protected. Differently named
workloads and direct Pod/ReplicaSet changes by administrators are not covered.
Infrastructure/frontend restrictions, namespace admission, OIDC, scoped DB/NATS
permissions, runtime enforcement and recovery remain open. Resource limits are
lab compatibility bounds, not production sizing or a performance result.

[Structured observations](2026-11-22-workloads-result.json).
Local final trading log: `/private/tmp/traderx-security-runtime/evidence/workloads-trading-final.log`.
Trading log SHA-256: `3bda030bed9c4fc3ae25c3ec2b28163a02652e5b50d36dfd47f1e04dfad3cca6`.
Thirty automated tests and all four repository quality gates passed. Browser QA
verified live results, the service/denial tables and evidence download.
