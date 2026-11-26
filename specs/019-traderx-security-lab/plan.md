# State 019 implementation plan

The current Phase 1/2 work follows the [integrated acceptance boundary](system/integrated-acceptance.md): authenticated application journey first, then the same journey under enforced deployment controls. Independent component campaigns remain checkpoints, not completion of either full phase.

The [completion assessment](system/completion-roadmap.md) groups the remaining
release gates and records a 5–10 focused-working-day planning range as of
26 November; this is not a completion claim or a calendar commitment.

The [26 November checkpoint](evidence/2026-11-26-phase-one-two.json) advances both
phases at source `5dd9f72d`: 47 live authenticated trading/delivery/API checks,
27 broker-session checks, 30 operator-directory checks, 38 Chrome component
checks plus production asset validation, and 30 real Kubernetes schema/admission
checks pass in [hosted run 45763236023](https://github.com/finos/traderX/actions/runs/45763236023).
The existing 51 browser/API checks and execution/delivery/process regressions
also pass; local regression is 297 Python tests. Three subagents supplied
independent trading, broker/UI and deployment work; all heavy execution ran in
GitHub. No new Copilot or Codex Cloud worker is claimed.

The [Python image checkpoint](evidence/2026-11-26-python-runtime-images.json)
closes S019-06a3a, revalidated at `04b42265`: three actual OCI images build and sixteen hosted
startup/configuration checks pass. Browser HTTPS, compiled assets, private mounts
and restricted execution are verified; worker images reject mismatched roles.
The runner uses verified TLS directly to its owned internal container address
because Docker suppresses host publication on that internal network. This is
not proof of a learner-facing port or successful image-based event delivery.
S019-06a3c records that positive worker-delivery gate explicitly.

The [actual browser checkpoint](evidence/2026-11-26-browser-journey.json) closes
S019-04e at `04b42265`: 24 browser checks and 13 independent SQL/delivery checks
pass through real Angular, Keycloak and trading services. Creation, settlement,
notifications, scoped views, cancellation, local logout and reader denials work.
Trader and reader use separate browser contexts; provider-wide logout is not
claimed. Same-campaign operator, expiry and full interruption checks remain in
the broader Phase 1 contract; this checkpoint does not close the whole phase.

The [packaged-worker checkpoint](evidence/2026-11-26-worker-image-delivery.json)
closes S019-06a3c at `1b40c4cc`: 43 hosted checks pass using actual immutable
images, verified SQL/broker TLS, twelve credential/certificate rejection cases,
publisher replay and consumer pre/post-commit recovery. Independent effects
remain one trade and one position projection; no business trade is rebooked.

S019-06a3b1 now has an implemented [private Spring/image contract](system/java-runtime.md),
verified build/OCI tooling and a dedicated hosted HTTPS/PostgreSQL acceptance
campaign. [Forty-one hosted checks pass](evidence/2026-11-26-position-image.json)
at `071df5a2`: verified HTTPS, scoped reads, identity denials, SQL TLS, failed
untrusted-CA startup before HTTP, private files and unchanged business data. Three
subagents implemented independent adapter, packaging and live-test work.
All seven [full regression jobs](https://github.com/finos/traderX/actions/runs/45900564353)
pass at that same functional source; local regression is 403 Python tests.
Copilot PR [#521](https://github.com/finos/traderX/pull/521) supplies a separately
reviewed .NET adapter candidate; actual .NET image acceptance remains b3.
Continue b2–b4 for the remaining Java/.NET services and support composition.
Provision issuer/broker/market-data TLS, complete their permitted gateway/egress
flows, and activate one cumulative cluster before closing S019-04/05/06. The
admission campaign uses synthetic OCI files and unscheduled probes; it is not
image provenance, network enforcement or runnable image acceptance. The new
core intentionally uses limit orders and omits legacy immediate booking. It
does not silently replace the retained nineteen-deployment C3 candidate.

1. Register the planned C3 child and review existing checkpoint evidence. Publish a draft portal preview and tracking issue.
2. Promote the profile into deterministic state generation/start/stop/test entrypoints; preserve pinned fixtures and earlier states.
3. Integrate identity into the trading UI and owning APIs, then cut over authenticated NATS with dynamic account subjects and browser credentials.
4. Integrate the TLS/WAF gateway, operator isolation, complete CNI policy graph, workload/SQL controls and signed-image admission. Re-run positive trading and negative checks together.
5. Implement the residual-authority canary, independent evidence and repeatable reset; select/pin and test one runtime observation/enforcement engine.
6. Finish staged learner UI, versioned CCC mapping, performance/resource checks and independent clean-machine/CI reproduction.
7. Publish only after acceptance review. CVE/OSERA is a separately gated optional exercise; supplier evaluation and the CALM successor remain separate workstreams.

See the [detailed plan](../012-platform-convergence-c3/security-lab/plan.md) and [release audit](../012-platform-convergence-c3/security-lab/state-readiness.md). Generation remains planned; registration must not expose a nonworking runtime command.

Offline generation checkpoint S019-03a is verified from a shallow clone; see [recorded evidence](evidence/2026-11-23-offline-checkpoint.json). The parent S019-03 task remains open until cumulative generation and runtime lifecycle entrypoints are integrated.

Composition preserves an explicit deployment blocker: the historical storage overlays require restore/initialization and SQL grants, so they cannot serve as fresh-cluster bootstrap. Finish S019-03c before exposing a generated start command; offline composition is S019-03b, not cumulative runtime acceptance.

S019-03b composition evidence is recorded in [the control-bundle result](evidence/2026-11-23-control-composition.json). All nineteen application deployments and the infrastructure collector are represented; the generated plan explicitly blocks deployment pending S019-03c.

Fresh database initialization is isolated as S019-03c1: a transactional schema/seed/grant compiler and bounded database campaign. The parent lifecycle task requires persistent credentials, Kubernetes bootstrap/restore and application rollout before deployment can be enabled.

The [24 November database campaign](evidence/2026-11-24-fresh-database-bootstrap.json) records two successful fresh initializations, exact service-grant checks, transactional failure recovery and preserved data/credentials on refusal. This completes S019-03c1, not full cluster lifecycle acceptance.

S019-03c2 provides create-once private identity persistence and verified reuse through the bootstrap SQL adapter. Next integrate it with owned Kubernetes Secret/PVC initialization and guarded start/stop; full deployment remains blocked.

S019-03c3 adds the database-only Kubernetes ownership/start/stop adapter and verifies the shared SQL initialization/resume path through two live PostgreSQL restarts. Live Kubernetes adapter acceptance is S019-03c4; telemetry and application rollout plus normal trading remain part of S019-03c.

S019-03c4 and S019-03c5 are live-validated: immutable SQL Secrets/PVC provisioning, transactional failure recovery, two database Pod recreations, and a fifteen-Deployment trading candidate with independent settlement/cancellation outcomes and a workload-admission denial. Next integrate fresh telemetry storage and collector migration, then the cumulative state entrypoints and full acceptance suite.

S019-03c6/c7 complete the candidate runtime lifecycle: non-root telemetry initializers, isolated collector, retained logs/metrics/traces/dashboard after recreation, all nineteen Deployments ready together, and passing trading outcomes after telemetry restart. Citrix remained running and host pressure stayed normal in sampled observations. S019-03c is complete for the local candidate; S019-03 still requires cumulative generation/fresh-clone entrypoints and the remaining security/release gates are unchanged.

S019-03d adds a checkout-relative contributor entrypoint, complete local runtime dependency hashes, verified dispatch and recovery stop independent of artifacts. Fresh shallow-checkout artifact reproduction passed with 156 Python tests; standalone generated-state packaging and clean-machine runtime acceptance remain open.

S019-03e introduces a read-only platform doctor before provisioning automation. It separates existing-platform readiness from enforcement proof and full infrastructure provenance. The existing Cilium lock records an observed agent digest, not a complete chart/operator artifact lock; fresh provisioning remains pending until those inputs and clean-machine behavior are verified.

S019-03f completes the selected Cilium artifact lock and reproducible infrastructure bundle. The fresh profile explicitly disables optional Hubble to avoid nondeterministic Helm-generated private TLS keys. Guarded cluster creation has offline failure-boundary tests; S019-03g remains the live fresh-platform acceptance gate. Existing cluster configuration is unchanged.

S019-03g1 now has fresh-cluster Cilium/network/admission evidence. Application image preload exhausted Docker storage (59 GB used, zero available), so full unattended setup/trading remains unaccepted. Only the new validation node's unused application cache was reclaimed; the original cluster was preserved. Resolve disk capacity before retrying, and validate the corrected startup flags and disk guard on the next full run.

Approved unused-build-cache cleanup reclaimed 5.08 GB. Reviewed recovery loaded all twenty pinned images and passed doctor plus nineteen-deployment startup (S019-03g2). The cumulative test timed out waiting for its initial synthetic Loki log marker; persistence and trading were not established by this run. Diagnose collector discovery/delivery and ingestion before rerunning S019-03g3. See [recovery evidence](evidence/2026-11-24-cache-recovery.json). This resumed retained cluster does not close unattended-create or clean-machine acceptance.

S019-03g3a identifies the log failure as Loki WAL disk throttling: collector file access and sink health passed, but pushes returned HTTP 500 at 90.48% filesystem usage. Added fail-closed checks for at least 2 GiB available and usage below 85%, preserving Loki’s protective threshold. The live high-usage refusal and 185 unit tests pass. Capacity recovery and cumulative telemetry/trading rerun remain pending; no new acceptance success is claimed.

S019-03g3 now passes after approved archival/retirement of the stopped State 014 cluster. Both security clusters were preserved, Docker capacity/RAM stayed unchanged, and filesystem usage fell to approximately 75%. The recovered validation cluster passes nineteen-deployment readiness, stored telemetry across recreation, collector boundaries, settlement and cancellation with independent SQL outcomes. See [consolidated-runtime evidence](evidence/2026-11-24-consolidated-runtime.json). This does not close uninterrupted fresh-create or independent clean-machine acceptance.

Identity integration follows the [trading authorization contract](system/trading-authorization.md): first direct API enforcement, then durable background execution, then remaining read APIs and Angular/session cutover. Anonymous scheduler execution must not be silently exempted to preserve a passing positive test.

S019-04a passes as a direct-API component candidate: deterministic trade/matcher overlays, signed-token HTTP checks and H2-backed stored-order denial/cancellation outcomes. See [component evidence](evidence/2026-11-24-trading-authorization-components.json). S019-04 remains open; no runtime image cutover or full Keycloak/Angular/background-settlement acceptance is implied.

S019-04b is split into persisted acceptance/eligibility (04b1) and authenticated durable execution (04b2). The candidate must refuse anonymous execution while the second part is incomplete. Both are prerequisites to runtime cutover; metadata is not a security boundary against a compromised database writer.

S019-04b1 passes 29 Java component tests (including five new durable-acceptance checks) and deterministic rendering. See [accepted-order evidence](evidence/2026-11-24-accepted-order-authority.json). The candidate deliberately refuses execution until S019-04b2, so neither background settlement nor runtime cutover is claimed.

S019-04b2a passes the real PostgreSQL [execution-ledger campaign](evidence/2026-11-24-execution-ledger.json), including concurrent duplicate settlement and rollback of trade/position/order/receipt together. The [delivery contract](system/execution-delivery.md) identifies remaining authenticated HTTP, Java processor, broker/event-outbox and cancellation integration. Candidate SQL is not deployed or included in fresh bootstrap yet.

S019-04b2b1 validates the processor service-only HTTP endpoint against real PostgreSQL, including concurrent duplicate requests and a processor/database restart. See [HTTP execution evidence](evidence/2026-11-25-processor-execution-http.json). The opt-in processor candidate disables legacy NATS and HTTP booking; matcher dispatch, token acquisition, deployment TLS/Keycloak and reliable event delivery remain open.

After baseline acceptance, run the [platform-control comparison](system/platform-control-comparison.md): ingress/gateway and service-mesh profiles measured against identical security outcomes and total implementation/operating effort. This is separate from the planned CALM successor; choose products, pinned compatibility and any successor state number during that exercise.

S019-04b2b2 adds the bounded service-token client with eight component tests; all 51 Java tests pass. See [token-client evidence](evidence/2026-11-25-service-token-client.json). Live identity provisioning and scheduler wiring remain open.

The parallel-agent pilot advances bounded components only: position/history API
authorization (04c1), matcher dispatch/cancellation (04b2b3), transactional event
outbox (04b2b4), independent SQL race/replay review (04b2b5), and a release-pinned
[CCC assessment map](system/ccc-assessment-map.md) (10a). The Linux workflow
consolidates sequential builds and database campaigns on a dedicated hosted
runner. Hosted Linux run 45559194453 passed the four builds and three SQL campaigns; full deployment and learner acceptance remain open.

Next integrate the authenticated broker publisher and durable consumer inbox,
then provision live matcher identity/TLS and run a single cumulative trading
campaign before enabling any candidate image. People authorization and Angular
session/CSRF integration remain parallel source work. Keep full-cluster acceptance
serialized and within the existing Docker resource limits. See
[the pilot checkpoint](evidence/2026-11-25-parallel-pilot.json) for measured results.

S019-04b2b6 now validates the authenticated TLS JetStream publisher and scoped
reference consumer projection: 41 live checks cover real broker/database restart,
acknowledgment-loss boundaries, replay outside broker deduplication, inbox/effect
atomicity, account restrictions and exact financial decimals. See
[evidence](evidence/2026-11-25-event-delivery.json). The existing Java/Node/browser
consumers still need envelope integration; fresh deployment credentials, TLS,
operator recovery and runtime packaging remain open. No main merge is authorized.

The next bounded checkpoint integrates reviewed cloud proposals #519 and #520:
the [supervised worker](system/delivery-worker.md) and an
[independent delivery campaign](system/event-delivery-adversarial.md).
Run their component checks locally without container downloads, then repeat the
real database/broker campaign sequentially on hosted Linux. Preserve the
agent-recorded evidence as historical evidence and report the independent run
separately. This does not close application consumer adoption, credential
provisioning/rotation, live worker subprocess recovery or deployed supervision.

S019-04b2b7/b8 now pass: 235 local Python tests (including 16 worker and five
adversarial component tests), all local spec gates, and independent hosted Linux
run 45616153660 with 41 original plus 24 adversarial delivery checks. Hosted docs
build and preview pass. Review corrected orderly shutdown during consumer binding.
See [cloud integration evidence](evidence/2026-11-25-cloud-integration.json).
Next prove actual worker subprocess stop/restart and resulting database state
(S019-04b2b9), then provision credentials and adopt existing application consumers.
The integration preserves cloud provenance without importing unsigned initial
plan commits. No Main merge or generated-state publication occurred.

The [process/application handoff](system/worker-process-recovery.md) now specifies
actual publisher and consumer process kills at controlled SQL boundaries,
followed by restart and independently observed state. Next, generated Angular
trade/position consumers treat settlement messages as invalidations and reload
scoped HTTP data, with coalescing, cancellation and reconnect refresh. Validate
both in hosted CI without downloading frontend dependencies or images locally.
This source candidate does not provision browser sessions or NATS credentials.

S019-04b2b9 passes 14 actual worker process checks in hosted Linux run
45617966137 at `3c72fc19`: broker acceptance before publisher kill, fenced replay
by a replacement process, consumer transaction rollback on kill, durable
redelivery, clean SIGTERM, idle restart and unchanged trading records. The SQL
blocking gates are synthetic; the worker kills and database effects are real.

S019-04b2b10 now passes with S019-04b2b9 in hosted run 45619682672
at `5041a837`: 14 process checks, eight Chrome component checks against the
actual blotter classes, and a production Angular build. Existing 41/24 delivery
campaigns also pass. See [process/application evidence](evidence/2026-11-25-process-application-consumers.json).
HTTP and feed doubles exercise browser component behavior; they do not establish
live authenticated end-to-end delivery. Next integrate browser sessions/CSRF,
scoped broker credential issuance/revocation, deployment TLS and cumulative
trading before enabling candidate images. Nothing merges to Main.

Next, S019-04c2 follows the [browser API session contract](system/browser-api-session.md):
an opt-in explicit route adapter, per-request access-token/trust-window checks,
CSRF-protected mutations and a hosted real Keycloak → cookie → Spring read API →
PostgreSQL campaign. Record scoped rows and unchanged database effects separately
from browser component tests. The existing account-only prototype remains
available. Angular session wiring, scoped broker issuance and accepted trading
writes remain later gates; no runtime cutover is implied by this campaign.

S019-04c3 extends the same source candidate with an Angular session gate and
same-origin API interceptor. The session server reports its expiry; client-side
expiry, sign-out and API 401 destroy account views and cancel outstanding reads.
The candidate disables anonymous NATS until the scoped broker checkpoint and
shows that limitation in the application. Hosted Chrome tests and a production
build must pass before marking this source integration complete. This is not yet
an application served by the cumulative deployment gateway.

S019-04c2/c3 now pass at `78e907c3`: hosted run 45624612985 records **51 live
Keycloak/session/Spring/PostgreSQL checks**, **18 Chrome component checks** and
the Angular production build, alongside the existing execution/outbox/delivery
campaigns. Local regression passes 242 Python tests and all required spec gates;
the learning sequence diagram parses. See [browser session evidence](evidence/2026-11-25-browser-api-sessions.json).
Chrome uses HTTP doubles while the API campaign uses a real issuer and database;
neither is complete deployed browser trading. Next integrate scoped broker
sessions/revocation, people-service authorization and matcher identity/TLS, then
serve and validate the combined frontend/API/worker candidate before rollout.
No screen sharing, local dependency/image installation, Citrix change, Main merge
or generated-state publication occurred.

## Phase one/two parallel execution — 26 November

User-authorized isolated agent worktrees own broker/session transport (05a),
authenticated trading acceptance (04d), and integrated deployment composition
(06a). The integration owner handles the operator-only directory (04c4), shared
workflow/status, review and hosted validation. Each track adds a contract and
tests before integration. GitHub jobs use separate runner filesystems; generation
within each job remains sequential. No local container/Java/npm downloads or
screen sharing is required, and Citrix stays untouched.

Phase one closes only after the combined supported login/order/cancel/settlement
and application-update journey passes with intended denials. Phase two closes
only after that same journey runs with all advertised deployment controls.
Offline compiler tests, component candidates and missing image/identity inputs
must not be relabeled as either completion gate.
