# Security Lab tasks

- [x] SL-T01 (FR-01/02) Create isolated main-based worktree and verify snapshot/source pins.
- [x] SL-T02 (FR-02) Implement snapshot inventory and document trust boundaries.
- [x] SL-T03 (FR-10, NFR-05) Implement deterministic candidate NetworkPolicy rendering and offline tests.
- [x] SL-T04 (FR-05/07) Implement evidence validation that rejects unsupported prevention claims.
- [x] SL-T05a (FR-01) Resolve and lock all 20 reference workload image digests from the pinned snapshot, recording architecture.
- [x] SL-T05b (FR-01) Run reference trading and capture positive evidence: full inherited State 010/011/012 smoke suite passed.
- [x] SL-T05c Correct inherited smoke readiness endpoints for trade-service/trade-processor to their supported Actuator health routes, with readiness regression checks; preserve source runtime behavior.
- [ ] SL-T06 (FR-03) Verify isolated Linux CNI/gateway/WAF/admission/runtime compatibility and pin versions.
- [x] SL-T06a Verify Cilium 1.20.5 allowed/denied network enforcement and Kubernetes Restricted admission in bounded fixtures in a dedicated cluster.
- [x] SL-T06b Run a pinned Coraza/CRS + standalone Envoy proxy-Wasm TLS comparison against a harmless recording backend; verify off/detect/block behavior and backend receipt. Envoy Gateway integration remains separate.
- [x] SL-T07 (FR-03) Implement and test workload/admission restrictions and writable-volume exceptions.
- [x] SL-T07a Implement and verify eight business-service restrictions, dedicated accounts and named-deployment admission under contracts/workloads.md.
- [x] SL-T07b Harden remaining gateway/frontend/database/broker/telemetry workloads and establish full namespace admission with separate infrastructure exceptions.
- [x] SL-T07c Harden six supporting services, exact writable mounts, and add direct-Pod admission for protected workload labels/identities; verify normal trading.
- [x] SL-T07d Migrate PostgreSQL off emptyDir with verified backup/restore and Pod-restart persistence; harden its workload and admission without changing SQL roles.
- [x] SL-T07e Isolate collector privileges, verify log cutover and enforce namespace-wide Baseline admission; preserve remaining observability history.
- [x] SL-T07f Preserve four observability stores on PVCs, verify retained data and workload restrictions, then enforce namespace-wide Restricted admission.
- [x] SL-T08-plan Specify roles, server-side account entitlements, strict token/session gates, route inventory requirements and browser-to-NATS dependencies.
- [ ] SL-T08 (FR-03) Implement OIDC roles/account authorization and authenticated operator routes.
- [x] SL-T09a Inventory live DB roles and four service consumers; specify minimum grants, migration/rotation and acceptance under contracts/database-permissions.md.
- [x] SL-T09b Implement and verify four scoped SQL identities, Secret-backed credentials, disabled matcher DDL, bootstrap-password retirement and credential admission; add ninth SQL experiment.
- [x] SL-T09c Rotate an individual runtime credential and verify old-login rejection, connection-pool drain and continued trading.
- [x] SL-T09 (FR-03, NFR-02) Implement per-service PostgreSQL roles, bootstrap separation and rotation.
- [x] SL-T10-plan Inventory pinned NATS clients/subjects and specify transport, permission and identity gates.
- [x] SL-T10a Add isolated TCP/WebSocket broker authorization demonstration with fixed synthetic accounts; 28 live cases passed on NATS 2.14.9, including 16 denials and 12 deliveries, with fixture cleanup. Console integration verified separately below.
- [ ] SL-T10b Add canonical client credential hooks and pin rebuilt images.
- [x] SL-T10b-node Add opt-in Secret-file/TLS credential hooks to the canonical price publisher; verify legacy startup, configuration rejection, real TLS price delivery, wrong-password and untrusted-CA rejection. Rebuilt image and live deployment are not included.
- [ ] SL-T10b-java Implement and test all five Java publisher/subscriber connections, including application reconnect and rotation.
- [x] SL-T10b-java-candidates Package three source/bytecode-verified bootJars into pinned-base local candidate images; verify JAR hashes and Java startup as UID 10001 on read-only containers. Full Spring startup/settlement and live rollout remain pending.
- [x] SL-T10b-java-adapters Verify all five real messaging adapters across fixture reconnect and credential replacement, including actual subscriber dispatch and disconnected-status regression; domain callbacks are fixtures, not full Spring settlement.
- [x] SL-T10b-java-hooks Wire one canonical Secret-file/TLS helper into five Java connections and generator fallback; real JNATS tests verify six deliveries, wrong password, untrusted CA and wrong hostname. Application lifecycle/reconnect/rotation and rebuilt images remain pending.
- [x] SL-T10b-c3-compat Import manifest-pinned candidates and roll out four image-only updates; full Spring startup, preserved workload settings and full inherited C3 trading smoke passed. Live NATS remains anonymous pending identity/subject cutover.
- [ ] SL-T10b-images Rebuild and pin affected client images; verify probes/explorer/browser compatibility before broker cutover.
- [x] SL-T10b-node-image Build the full canonical Node candidate from pinned base and lockfile; verify image source hashes, non-root/read-only runtime, authenticated price delivery and health. Local config-ID pin only; no publication or live rollout.
- [x] SL-T10b-node-lifecycle Verify real Node publisher reconnect after fixture broker restart and password rotation through explicit process replacement; require fresh prices and retired-login rejection.
- [ ] SL-T10c Specify and verify profile subject migration for dynamic accounts, preserving earlier states.
- [ ] SL-T10d Integrate verified user/account identity and live C3 broker authorization.
- [ ] SL-T10 (FR-03, NFR-01) Implement NATS authentication and exact account-subject permissions with positive and negative checks.
- [ ] SL-T11 (FR-03) Complete observed flow graph and verify network enforcement and image trust admission.
- [ ] SL-T12 (FR-05/06/07) Build bounded compromise fixture, same-process DB canary, reset, asynchronous settlement and external evidence collector/dashboard.
- [ ] SL-T13 (FR-08) Verify CCC release/assessment requirements and collect control evidence.
- [ ] SL-T14 (FR-04/09, NFR-04) Compare runtime profiles and performance; await supplier integration contract for candidate runs.
- [ ] SL-T15 Publish local walkthrough and independently reproduce first release; no remote publication is authorized.
- [ ] SL-T16 Create a separate CALM follow-on state after security acceptance: model existing boundaries, generate supported controls, verify equivalent outcomes and compare bolt-on versus model-first effort. State number undecided; see learning-objectives.md.
- [x] SL-T17 (FR-11) Specify, implement and verify a loopback-only experiment console with fixed bounded actions, serial execution, historical/current evidence, download and roadmap. Does not complete SL-T12.

Docker's failed engine proxy was repaired by restart. An isolated kind cluster now exists with its own kubeconfig. User chose to stop state-014 instead of increasing Docker RAM: its control-plane container is stopped, preserved and resumable; Docker remains at 6 GB. The default kubeconfig is unchanged. Both clusters are now stopped for lightweight account development; start full C3 only for a separate acceptance session.

- [x] SL-T18 User-authorized temporary authenticated ngrok console; exact public origin, CSRF/Host restrictions and remotely verified experiment/evidence download. No repository publication.

- [x] SL-T18b Replace reported Basic Auth prompt loop with cookie sign-in gateway; verify actual browser login and remote experiment.

- [x] SL-T19-plan (FR-12/13) Specify learning objectives, separate CALM progression and bounded CVE/OSERA analysis contract.
- [ ] SL-T19a Select one CVE with upstream advisory/fix, pinned vulnerable/fixed artifacts and harmless reachable reproducer.
- [ ] SL-T19b Implement isolated CVE fixture, control comparison, fixed-version regression, positive controls and two reset cycles; no direct tunnel exposure.
- [ ] SL-T19c Integrate pinned OSERA VEX statements, exact artifact/provenance matching and source patch analysis; compare upstream upgrade and OSERA backpatch with the same regression tests and visible scanner/VEX results.
- [ ] SL-T19d Add verified CVE console exercise, sanitized evidence and learner assessment.

- [x] SL-T10a-ui Add the verified isolated NATS scenario to the console with bounded execution and sanitized evidence; browser run and authenticated remote evidence download passed.

- [x] SL-T20-map (FR-14/15) Generate an evidence-linked Mermaid progression and specify bounded residual-risk experiments; no exploit outcome claimed.
- [ ] SL-T20-navigator Add learner-facing phase navigation, checkpoint setup/reset and guided assessment after checkpoint acceptance.
- [x] SL-T08-account-inventory Inventory eight account/membership routes and identify the entitlement-mutation boundary; enforcement is tracked separately below.

- [x] SL-T08-provider Prove isolated pinned OIDC sign-in, S256 PKCE, strict token rejection and trusted entitlement mapping under contracts/identity-fixture.md; live API enforcement remains separate.

- [ ] SL-T08-account-enforcement Add opt-in Spring token validation and trusted entitlement checks to actual account/membership routes; prove filtered lists, permitted/cross-account detail reads, denied ordinary-user membership writes and normal workflows before cutover.

- [x] SL-T21a (FR-16) Specify operating modes, implement read-only resource preflight and enforce it before identity-provider startup; unit-test unsafe/unknown observations.
- [x] SL-T21b Integrate capacity policy and explicit mode selection across console experiments and heavyweight build runners.
- [ ] SL-T21c Measure full-C3 service budgets and startup peaks; validate integrated acceptance separately.

- [x] SL-T21c-dev Render and verify the three-container account development environment, scoped SQL identity, candidate-jar hook, two retained-container reset cycles and a clean final dataset. Record sampled memory and correct accountuser account-ID semantics.

- [x] SL-T08-account-local Implement the opt-in Spring candidate, public-key token validation, server-owned account scopes and deny-all user writes; pass 59 real API cases in each of two reset cycles with independent unchanged SQL state. Test signer only; C3 cutover and real-provider integration remain pending.

- [x] SL-T08-account-provider Integrate actual TLS/PKCE provider tokens with the protected Spring candidate; verify role/account reads, rejected mutations, independent SQL state, explicit retired-key rejection and provider-outage behavior. Keep browser/session and live C3 acceptance separate.

SL-T08-account-provider evidence: 49 initial and 50 key-replacement checks passed.
SL-T08-account-enforcement remains open for browser/user-context integration and
full-C3 normal-trading acceptance; local provider/API success does not close it.

- [x] SL-T08-browser-local Implement the loopback HTTPS account-session backend and page; verify real provider redirects/cookies, server-only tokens, role/account scope, callback replay/state defenses, CSRF/logout invalidation and unit-tested expiry. This does not close Angular/full-C3 browser acceptance.

- [x] SL-T08-browser-persistent Add bounded persistent runner/start-stop lifecycle, same-profile provider-confirmed account switching and actual Chrome usability evidence. Record localhost certificate trust explicitly; no warning bypass or public tunnel.

- [x] SL-T08-browser-switch Verify 24 same-cookie-jar checks for reader → trader → operator with provider-confirmed logout, CSRF denials, retired local-session rejection and unchanged SQL state. Actual Chrome remains a separate certificate-dependent gate.

- [x] SL-T08-browser-runner Verify persistent runner readiness, stop/closed ports, restart with retained TLS certificate, resource-operation exclusion, and 63 session/switch protocol checks. SL-T08-browser-persistent remains open for actual Chrome acceptance pending localhost certificate-trust approval.

- [x] SL-T22-design Specify contributor-local trusted HTTPS versus hosted learner onboarding, explicit trust scope/consent, private CA handling, resource checks and cleanup in contracts/learner-onboarding.md.
- [ ] SL-T22-local Implement guided setup/doctor/start/stop/reset, approved development CA integration and clean-machine browser verification on supported platforms.
- [ ] SL-T22-hosted Specify and validate a hosted, authenticated, isolated learner environment with publicly trusted TLS before exposing experiments remotely.

Chrome follow-up: explicit user-approved SSL trust of the exact lab certificate enabled
actual reader/trader login, account isolation, provider-confirmed switching and local
logout verification. See evidence/2026-11-23-chrome-browser.json. The prior certificate
blocker is resolved; full Angular/C3 acceptance and learner onboarding tooling remain open.

- [x] SL-T23-audit Record the first-class C3-child state decision, publication blockers, core/optional scope and promotion sequence in state-readiness.md.
- [x] SL-T23-story Specify the docs landing page, canonical Mermaid map, curated screenshots, exercise pages, captioned demo and community announcement draft in community-introduction.md; no publication or outbound messages.
- [ ] SL-T23-state Register a collision-free state ID and root feature pack, catalog lineage, generation/runtime/test hooks and learning contract while preserving C3.
- [ ] SL-T23-portal Generate the state guide/navigation/graph, capture pinned sanitized screenshots, render Mermaid, build/preview/check docs and independently reproduce the walkthrough before approved publication.
