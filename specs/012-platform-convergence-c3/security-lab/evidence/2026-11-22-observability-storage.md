# Observability cutover and namespace Restricted admission

Local verification on 2026-11-22, dedicated kind-traderx-security-lab context.
Canonical contract: ../contracts/observability-storage.md. SL-T07f completes the
SL-T07/SL-T07b workload slice; it does not complete hardened-profile acceptance.

| Store | Restored regular files matched by SHA-256 | Historical API proof |
| --- | ---: | --- |
| Grafana | 550 | All 11 dashboard UIDs retained |
| Prometheus | 4 | Identical fixed-time up vector |
| Loki | 54 | Pre-cutover synthetic log marker retained |
| Tempo | 1306 | Existing trace span IDs retained |

All four 2Gi RWO local PVCs are Bound. Every restored regular file matched its
private archive before the service started. All four processes run UID/GID 10001,
read-only root, no capabilities/escalation, RuntimeDefault and no API token.
Thirteen unsafe Deployment changes and four direct-Pod/debug changes were denied
with valid positives. Named SQL/broker roles were not changed.

Namespace activation checked all nineteen Deployment templates/readiness and a
namespace-label dry-run before enforcing Restricted v1.35. Twelve unrelated-name
Pod violations were rejected. Separate collector verification retained thirteen
infra-policy denials, scoped API permissions and fresh log delivery to Loki.
Business (8), supporting (6), database (1) and telemetry (4) process verifiers passed.
The full inherited State 010/011/012 trading smoke suite passed after migration.

Forty-one unit tests, JavaScript syntax and all four repository quality gates passed.
Browser-run observability experiment `9dfb28d6-38b9-437e-a3c2-717e0f96a438` passed.
The result displayed all four processes, thirteen denials and four bound PVCs with
historical retention checks. Its evidence download returned the structured bundle.
Screenshot: private runtime `observability-console.png`.

The first Grafana restore failed with ENOSYS from GNU tar in the emulated AMD64
helper. No store was started from that failed copy. The pinned ARM64 BusyBox helper
restored the checkpoint successfully; every file hash was checked before startup.
Admission negative tests also exposed a missing-resource CEL error; presence guards
now produce intentional denials without expression errors or type warnings.

Limitations: brief collection interruptions and duplicate replay are possible.
These local crash-consistent checkpoints are not production backups or HA proof.
PVCs do not survive cluster deletion; evidence/private archives remain mutable on
the local host. Restricted alone does not mandate read-only roots, resource bounds
or token suppression for arbitrary new workloads; named policies add those controls.
Collector root/host-log/API-token exceptions are explicit. Gateway, network, image
trust, OIDC, scoped SQL/NATS permissions and runtime protection remain roadmap work.

Smoke log SHA-256: `59457ab790c38002b6c728daf40987b46c6e620a81dfaeb86efa3e5f8a94ad9a`.
