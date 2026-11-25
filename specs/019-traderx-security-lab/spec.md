# State 019: Security Lab specification

## Intent and assumptions

Carry forward C3 trading and observability; add staged, attributable security learning. Protect synthetic accounts, order/trade integrity, credentials, availability and independent evidence. Threat actors are an outsider, an authenticated user, and an assumed-compromised application process. Kernel/cluster administrator compromise is out of scope for the first release.

## Functional requirements

- **FR-019-01:** Generate a cumulative C3 child with pinned source, images and control configuration; preserve reference C3.
- **FR-019-02:** Maintain positive trading while enforcing gateway/TLS/WAF, business authorization, workload/admission, network, scoped SQL, NATS subjects and approved-image boundaries.
- **FR-019-03:** Compare WAF disabled/detection/blocking with all other inputs fixed. A rejected request is not proof of a successful exploit in the disabled case.
- **FR-019-04:** Provide a bounded assumed-compromise exercise: deny a write outside grants, then measure a business-unauthorized write within service grants using the same process/client. Independently inspect the synthetic canary and settled downstream effects.
- **FR-019-05:** Compare one open-source runtime engine in observation and enforcement modes against the same scenarios. An alert or process termination alone cannot establish prevention.
- **FR-019-06:** Guide learners through prediction, execution, attribution, state inspection, reset and assessment; export sanitized, correlated evidence and versioned CCC mappings with limitations.
- **FR-019-07:** Provide an optional isolated CVE/upstream-fix/OSERA backpatch branch with matched component/provenance/VEX and reachable reproducer. Do not downgrade the hardened baseline implicitly.

- **FR-019-08:** Startup must verify cluster and resource ownership, reuse private SQL identities, and initialize only an empty database. Restart must preserve committed data without reseeding; stop must retain owned storage and credentials. Missing storage or a mismatched lifecycle binding requires explicit recovery.

- **FR-019-09:** Initialize telemetry volumes under a dedicated non-root tokenless identity, retain evidence across graceful pod recreation, and isolate the log collector exception with scoped admission and read-only discovery permissions. Verify actual stored logs, metrics, traces and dashboard state; service readiness alone is insufficient.

## Nonfunctional requirements

- **NFR-019-01:** Run one full cluster at a time; serialize heavy experiments, expose resource preflight and lightweight checkpoints, and measure memory/startup/latency/throughput.
- **NFR-019-02:** No real customer data, credentials in source, public unauthenticated experiment runner, or evidence under sole control of the compromised process.
- **NFR-019-03:** Fresh-clone reproducibility, deterministic reset twice, pinned artifacts and positive/negative CI are release gates.
- **NFR-019-04:** Label fixture, candidate, integrated and planned results distinctly. No certification or production-readiness claim follows from local checks.

## Acceptance scenarios

1. Given a valid reader identity, own-account reads succeed and other-account access fails; independent SQL proves denied writes caused no mutation.
2. Given the same benign and suspicious HTTP inputs in each WAF mode, record backend receipt and gateway decision separately.
3. Given scoped SQL and enforced networking, outside-grant writes fail; within-grant canary misuse records its actual effect and any intervening control.
4. Given a completed experiment, reset twice and repeat normal trading with stable evidence attribution.
5. Given a supported clean machine, a contributor follows onboarding and explains the boundary using exported evidence without maintainer intervention.

6. Given broker acceptance followed by a lost publisher acknowledgment, retry the same event and retain one business settlement; replay beyond broker deduplication must still apply a consumer effect once.
7. Given consumer commit followed by a lost broker acknowledgment, redelivery must leave its projection unchanged; forged, cross-account and stale messages must not overwrite the authorized projection.


Detailed threat assumptions, control contracts and existing evidence remain canonical in the [experimental specification](../012-platform-convergence-c3/security-lab/spec.md). State acceptance is pending; local checkpoint counts are not integrated acceptance.

### Contributor packaging requirement

FR-019-10: Provide a checkout-relative entrypoint for deterministic artifact generation and verified candidate start/test. Record transitive local runtime source hashes, require explicit runtime/cluster identity, and refuse artifact drift before runtime dispatch. Recovery stop must remain available after artifact drift while preserving ownership and cluster checks. Offline commands must start no containers or change local trust.

FR-019-11: Provide a read-only platform doctor that verifies artifact integrity, supported host, explicit context, private SQL identities, available resources, recorded cluster UID, pinned single-node image/version/architecture/readiness and observed Cilium agent readiness/digest. Unknown or unavailable observations must block readiness. A stopped cluster must not be started implicitly. Readiness must not be presented as proof of network enforcement or complete infrastructure provenance.

FR-019-12: Fresh infrastructure setup must verify chart archive, deterministic rendered resources and full selected container/init-container inventory against committed pins. It must refuse existing clusters, containers and setup directories, use an explicit private kubeconfig, serialize against the browser lab, preserve partial resources on failure, and never create persistent secrets in review bundles. Fresh platform creation is not enforcement or hardened-state acceptance.

FR-019-13: Fresh validation may use only the explicit supported alternate cluster name and a separate private runtime/kubeconfig. Record selection once, preserve existing stopped clusters, refuse other running control planes and concurrent account-development workloads, and require the recorded cluster UID for alternate-cluster network probes.

FR-019-14: Settlement notifications must survive publisher and consumer restart without rebooking trades. Persist events atomically with settlement; acknowledge the outbox only after authenticated durable broker acceptance. Apply each consumer event ID and its projection effect in one database transaction, retain deduplication beyond the broker's duplicate window, and reject older position snapshots. Bind consumer account permissions to the database login and broker identity, not event fields supplied by a caller. Tests must inspect final database effects after lost acknowledgments and replay. Supervised workers must use private configuration, verified transport (with an explicit loopback-only SQL fixture exception), bounded retries and shutdown, account-scoped consumption and secret-free status. A stop during connection or subscription setup must be distinguishable from a terminal failure. Independent malformed/canonical-envelope checks must verify the exact denial layer and unchanged authoritative effects. Component supervisor tests do not establish real process-crash recovery. A single-node fixture does not establish high availability or power-loss durability.
