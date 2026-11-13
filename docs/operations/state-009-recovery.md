# State 009 recovery and generator follow-up

Full refresh umbrella: [#486](https://github.com/finos/traderX/issues/486). Tracking: [#487](https://github.com/finos/traderX/issues/487), recovery [PR #488](https://github.com/finos/traderX/pull/488), publishing prerequisite [PR #485](https://github.com/finos/traderX/pull/485).

## Recovery evidence

- Local state-009 regeneration completed on 2026-11-11.
- Read-only [host diagnosis](https://github.com/finos/traderX/actions/runs/42973739192) found no containers, NGINX forwarding to the inactive localhost:8080 upstream, and the existing named PostgreSQL volume `traderx-009-order-management-matcher_postgres_state_009_data`. No host runtime was changed by diagnosis.
- Preserve and back up this volume before replacement. Root disk had 4.2 GiB free; check capacity before pulling the replacement.
- Rebuilt PostgreSQL 16 and blackbox-exporter v0.29.1 candidate scans have zero HIGH/CRITICAL findings. Loki and Prometheus rebuilds also passed the host-policy scan. Tempo 3.1.1 passed with Trivy 0.76.2; Trivy 0.69.3 misidentified the root module as a pre-release Go pseudo-version. The pinned updated scanner inventories the verified 3.1.1 release and its patched dependencies, with no additional suppression. Raw reports from both versions are retained locally. Vector 0.61.0-alpine has zero HIGH/CRITICAL findings and is the candidate maintained Docker log collector.

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
- [ ] Add meaningful application/ingress/broker/observability readiness and trading-flow/persistence acceptance tests; fix the public Prometheus route, invalid collector health-port scrape, and prove live application trace export.
- [ ] Keep database-volume detection, backup and restore checks in the deployment path.
- [ ] Reconcile #485 and #488 into main, then regenerate descendants sequentially through the supported publisher.
- [ ] Remove the scoped Grafana disposition when upstream metadata/scanner evidence no longer needs it, and never extend it automatically.

## Final generated candidate

Snapshot `bb97d232904bbd2aea73d8702302b4e25006cd09` was published from source `a7a09d48` through the supported publisher. Its sole parent is state-008 snapshot `384e3c02e13417d1d9b06522c2800c503f9eb2af`; contract and lineage validation passed.

All exact-head CI completed successfully:

- [Build/test](https://github.com/finos/traderX/actions/runs/42980225780)
- [Build/publish: 15 images](https://github.com/finos/traderX/actions/runs/42980225786)
- [Security: 25 jobs](https://github.com/finos/traderX/actions/runs/42980226188)
- [License](https://github.com/finos/traderX/actions/runs/42980225904)

Local deployment regressions: 27 passed. All four repository quality gates passed; workflow YAML and embedded shell syntax validated.

## Live recovery result — 2026-11-11

[Deployment 42981784916](https://github.com/finos/traderX/actions/runs/42981784916) successfully deployed `bb97d232904bbd2aea73d8702302b4e25006cd09` after all nine host scans passed. Eight images have no HIGH/CRITICAL findings; Grafana has only the two approved already-fixed findings. [Preflight artifacts](https://github.com/finos/traderX/actions/runs/42981110497) and deployment artifacts retain raw reports.

The existing PostgreSQL 16 volume was preserved and backed up before starting containers. Backup SHA-256: `bbcdc9d4e6338f839b871e2f1340103d9e7f357deaea727a3a296c636266e7ae`; the private backup remains on the host. [Post-deployment diagnosis](https://github.com/finos/traderX/actions/runs/42982479252) records the path, snapshot, pinned service images and all 19 running containers. Root disk has 8.2 GiB free (59% used).

Verified live:

- Public HTTPS application and ingress health return 200; UI identifies state 009 and displays Message Bus Connected.
- Trade service, trade processor and order matcher report connected messaging; NATS WebSocket CONNECT/PING/PONG passes.
- Order create/list/cancel (`ord-013-0008`), force-fill (`ord-013-0009`), settled trade creation and position update (JPM 0 to -3), and automatic price-driven fill (`ord-013-0010`) pass.
- Fresh API requests and browser reload preserve settled trades and positions.
- Grafana, Prometheus, Loki and Tempo local readiness endpoints return 200. Loki returns live container logs. Grafana's Prometheus datasource returns four connected-message-bus series; all 14 blackbox HTTP probes succeed.

Known remaining observability work: the inherited public `/prometheus/` route returns 404; port 13133 is incorrectly included as a Prometheus metrics target (collector metrics on 8888/8889 work); live Tempo search returned no application traces, although the rebuilt Tempo passed local OTLP ingestion/query. These are explicitly unfinished generator/acceptance tasks, not security exceptions or a claim of complete cross-state observability validation.

Recovery is complete for the application demo. Cross-state remediation and complete runtime CI gating remain open under #486 and #487.

## Final runtime compatibility checks

- Tempo 3 monolithic configuration validated; OTLP trace ingestion and trace-ID query passed.
- Vector configuration validated; Docker log ingestion into Loki and label-filtered query passed.
- Collector configuration validated with its current debug exporter and explicit port 8888 metrics reader.
- Prometheus builds only the static-target discovery support needed by state 009, omitting unused cloud discovery plugins; its release tag is verified against the pinned source commit.
- Final host scanner is Trivy 0.76.2 pinned by image digest. HIGH/CRITICAL vulnerabilities and secrets remain blocking; only the previously approved Grafana disposition applies.

Host capacity diagnosis confirmed 15 GiB available RAM and 7.8 GB of unused image cache, with no containers. Recovery can explicitly reclaim images older than 24 hours through a state/host-scoped option that refuses nonempty container inventories. No volumes are pruned. This provides room for the replacement and Loki WAL disk headroom.
