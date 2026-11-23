# Supporting workloads — 22 November 2026

SL-T07c is complete. Together with SL-T07a, fourteen of twenty C3 workloads now
have the tested non-root, read-only-root, token-free restrictions. This is not full
namespace hardening or broker authorization.

## Results

Browser run `35959645-8f02-464b-a96f-dee04f200794` passed. The evidence endpoint's
artifact hash matches its JSON payload. Six live processes were checked through
CRI and /proc: NATS, blackbox exporter, OpenTelemetry collector, static frontend,
API docs and edge proxy. Each has UID/GID 10001, zero capabilities, no-new-privileges,
seccomp filtering, read-only root and no API token. Actual resources, mounts,
readiness and identity permission denials were checked. Gateway /tmp write/remove
succeeded; root write failed with `Read-only file system`.

Eleven unsafe Deployment mutations were rejected by the support admission policy.
Valid direct-Pod dry-runs passed for representative business/support workloads;
eight root/label/identity/debug-container mutations were denied by their respective
Pod policies. Debug checks used the actual ephemeralcontainers subresource with
`dryRun=All`; no debug container was created. Policy type checking reports no
warnings. Both protected-label and protected-identity matching paths were tested.

The eight business processes and their eleven Deployment denial checks passed
again after the supporting rollout. The full inherited C3 trading smoke passed,
including APIs, NATS-dependent trade processing, frontend/docs and observability.
All twenty Pods are ready. No additional database restart occurred (its previous
restart count remains two); all newly hardened supporting Pods have zero restarts.

## Implementation and correction notes

The actual pinned frontend image serves static files with Nginx, unlike the
snapshot's development Dockerfile. The profile preserves that image and runs Nginx
directly, with bounded /run and cache mounts. API docs moved from container port
80 to 8080 with a matching Service target; external routes are unchanged.

An initial hostPath negative fixture replaced all volumes and was schema-invalid.
It now replaces only the tmp volume, preserving required mount references; only
policy-attributed denials count. An evidence source-filename bug was corrected
before the final repeat. Neither incomplete run was treated as passing evidence.

## Remaining boundary

Pod admission matches protected app labels OR protected service accounts. An
administrator who changes both can create an unrelated workload; namespace-wide
admission remains open. PostgreSQL, Grafana, Prometheus, Loki, Tempo and the
host-log collector retain their prior posture. No storage migration was performed.
NATS authentication/subject ACLs, OIDC/business authorization, gateway WAF/TLS,
network segmentation, image trust, runtime protection and recovery remain separate.
CALM remains deferred.

[Structured observations](2026-11-22-support-workloads-result.json).
Final trading log: `/private/tmp/traderx-security-runtime/evidence/support-trading.log`.
SHA-256: `7fba87784c0a2e413422fe710a32987221a79d306ec58fc56dec2b35789a0776`.
33 automated tests and all four repository quality gates passed. Browser QA verified
the fifth experiment, live per-service results and both admission result tables.
