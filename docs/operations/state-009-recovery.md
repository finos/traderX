# State 009 recovery and generator follow-up

Tracking: [#487](https://github.com/finos/traderX/issues/487), recovery [PR #488](https://github.com/finos/traderX/pull/488), publishing prerequisite [PR #485](https://github.com/finos/traderX/pull/485).

## Recovery evidence

- Local state-009 regeneration completed on 2026-11-11.
- Read-only [host diagnosis](https://github.com/finos/traderX/actions/runs/42973739192) found no containers, NGINX forwarding to the inactive localhost:8080 upstream, and the existing named PostgreSQL volume `traderx-009-order-management-matcher_postgres_state_009_data`. No host runtime was changed by diagnosis.
- Preserve and back up this volume before replacement. Root disk had 4.2 GiB free; check capacity before pulling the replacement.
- Rebuilt PostgreSQL 16 and blackbox-exporter v0.29.1 candidate scans have zero HIGH/CRITICAL findings. Loki/Tempo/Prometheus rebuild validation remains in progress. Vector 0.61.0-alpine has zero HIGH/CRITICAL findings and is the candidate maintained Docker log collector.

## Grafana 12.4.15 fixed-source findings: approved scoped disposition

The immutable Grafana image in `catalog/security/state-009-grafana-fixed-findings.json` has two HIGH findings against its Tempo module's Go pseudo-version. Both upstream fixes are already ancestors of the source revision embedded in the scanned binary:

- [CVE-2026-21728 advisory](https://grafana.com/security/security-advisories/cve-2026-21728/): [fix-to-embedded-source comparison](https://github.com/grafana/tempo/compare/650eb1985a0776789c8564122990f588a742356f...525d1bab07e0) is ahead by 337 commits, behind by zero.
- [CVE-2026-28377 advisory](https://grafana.com/security/security-advisories/cve-2026-28377/): [fix-to-embedded-source comparison](https://github.com/grafana/tempo/compare/bb8ca663db34a0980c9758b40d918fda3b4dbec3...525d1bab07e0) is ahead by 218 commits, behind by zero.

The candidate disposition is limited to these two IDs, this exact image digest, this exact package/version, with expiry 2026-12-11. It must not exclude either CVE from any other image or version. Raw reports must be retained and these findings recorded as already fixed, separately from zero-finding scans. Any additional finding, changed digest/version, expired disposition or scanner error must block deployment. The user explicitly approved this exact disposition on 2026-11-11. The deployment helper applies it only to the matching immutable image, package/version and CVE before expiry, retaining the raw reports and disposition in scan summaries.

## Main-generator work to complete after recovery

- [ ] Fold validated runtime versions, reproducible rebuild inputs and compatible configuration into canonical generation; preserve predecessor and descendant behavior.
- [ ] Replace legacy Promtail with a maintained log collector and preserve dashboard labels and log coverage.
- [ ] Implement complete Runtime Image Security CI inventory/evidence for all publishing states, including Kubernetes init/sidecar containers.
- [ ] Bind infrastructure digests to exact snapshot/run/attempt/platform and enforce freshness and complete host coverage before SSH.
- [ ] Add meaningful application/ingress/broker/observability readiness and trading-flow/persistence acceptance tests.
- [ ] Keep database-volume detection, backup and restore checks in the deployment path.
- [ ] Reconcile #485 and #488 into main, then regenerate descendants sequentially through the supported publisher.
- [ ] Remove the scoped Grafana disposition when upstream metadata/scanner evidence no longer needs it, and never extend it automatically.

## Completion evidence still required

Exact generated SHA and one-snapshot ancestry; successful required CI runs; all-image scan reports and approved dispositions; database backup; deployment run; public ingress and message-bus health; order create/cancel/fill; settled trades and positions surviving reload; observability queries. This document does not claim recovery is complete.
