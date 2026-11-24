# State 019 implementation plan

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
