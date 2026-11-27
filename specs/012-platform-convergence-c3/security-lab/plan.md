# Security Lab implementation plan

## Architecture and constitution

Canonical profile artifacts live inside the existing numbered C3 feature pack. No new state number, parent change, generated snapshot edit or baseline behavioral change. The generator is opt-in. Evidence-gated delivery applies independently to each milestone; unchecked runtime work cannot be reported as complete.

Browser/test runner → TLS + Coraza/CRS gateway → authenticated APIs → PostgreSQL/NATS. Browser NATS connections require short-lived scoped credentials. Application authorization must validate issuer, audience, signature, expiry and account ownership server-side. OIDC login at the gateway alone is insufficient. Operator observability routes use a separate authenticated boundary. Runtime agents and authoritative evidence collection live outside the application namespace.

## Milestones and dependencies

| Milestone | Implementation | Exit evidence |
| --- | --- | --- |
| M1 Baseline | Pin snapshot/source; inventory static routes, identities, subjects and flows; capture image digests; run reference trading | Reproducible lock, trust map, live positive controls |
| M2 Compatibility | Dedicated Linux kind cluster with policy-enforcing CNI; test Coraza/Envoy integration, admission and Tetragon hooks; pin tested chart/image/kernel versions | Actual denied and allowed traffic; WAF mode comparison; supported-hook proof |
| M3 Hardening | Service accounts/token suppression, restricted pod settings/resources; route segregation; OIDC/account authorization; bootstrap/runtime DB grants; secret injection/rotation; NATS subject ACLs; supply-chain admission | Positive trading plus negative checks attributed to each layer |
| M4 Demonstrations | Correlated harness, isolated assumed-compromise fixture, DB canary via existing client/connection, reset, evidence view | Repeatable result and asynchronous settlement, external evidence |
| M5 CCC | Verify versioned catalog assessment requirements and link each selected scenario | Traceable results with unsupported requirements explicit |
| M6 Evaluation | Observation vs enforcement vs supplier, fixed workload and benign variations | Incremental impact, overhead, failure behavior; supplier contract required |
| M7 Learning | Walkthrough, architecture explanation, runbook and reproduction check | Independent contributor reproduces and explains results |

M1 static work and policy compilation can proceed without Docker. M1 runtime and M2 require a functioning Linux container runtime. M3 requires verified M2 compatibility; M4's impact claims require M3 controls. M5 mapping can be drafted earlier, but results follow M4. Do not choose component versions by copying an untested documentation example.

## Initial executable slice

The local [experiment console](contracts/console.md) adds a buildless HTML/CSS/JavaScript frontend served by a Python standard-library loopback server. A fixed command registry invokes the existing baseline/platform/WAF harnesses serially; private per-run directories preserve evidence. It introduces no public hosting, arbitrary command interface or new dependency. Complete remaining control-specific designs before implementing their application/runtime changes; the initial broad specification is not a substitute for those detailed contracts.

`scripts/security-lab/lab.py` inventories the exact fetched snapshot, renders a standalone default-deny NetworkPolicy candidate from explicit flow contracts, and validates result evidence. It never applies resources or starts attacks. Policies are incomplete candidates until DNS behavior, telemetry, gateway namespace, probes and all positive flows are verified in M2. No broad external egress exception is generated.

Workload hardening follows image compatibility tests: specify non-root UID, no privilege escalation, all capabilities dropped, RuntimeDefault seccomp, read-only root with named writable mounts, dedicated accounts without API tokens, requests/limits and admission. Database and observability containers need separately tested mounts/UIDs. Namespace Restricted admission alone does not establish all these controls.

## Validation

Run unit tests for policy direction/port boundaries, unknown flows, pin/source mismatch and evidence false-positive rejection. Render JSON Kubernetes resources offline and review them. Run repository frontmatter, root SpecKit, readiness and coverage gates. Website build only if dependencies exist. Runtime validation remains separately recorded; never deploy to the user's current context implicitly.

## Learning progression and separate CALM state

Deliver [explicit learning objectives and assessments](learning-objectives.md) with this security profile. Then create a separate CALM follow-on state: bolt a model onto the verified implementation and compare with a model-first workflow using identical security tests. State number and tested tooling remain undecided; model-derived configuration must prove parity before replacing manual implementation.

## Optional CVE remediation exercise

After M3 baseline acceptance, implement [one CVE exercise](contracts/cve-patch-analysis.md) alongside M4. First select and pin a reproducible vulnerable/fixed pair; then build the isolated fixture and regression/reset checks. Integrate pinned OSERA OpenVEX/CycloneDX evidence and exact artifact provenance; compare an available OSERA backpatch with the upstream upgrade using the same regression tests. Compare source-linked analysis with runtime results. Do not downgrade the reference deployment or expose the fixture through ngrok. Include the exercise in M7 assessment; it does not block unfinished NATS and identity work.

## Rollback and migration

Reference C3 generation remains untouched. Recreate only the dedicated lab cluster to reset infrastructure; restore synthetic data through a separately privileged reset job. Retain immutable external run evidence. No live cluster deletion or automatic credential rotation is performed by this initial slice.

### Staged workload rollout

[Business workload contract](contracts/workloads.md) delivers SL-T07a against the already verified admission/CNI subset of M2. Integrated gateway and runtime compatibility remain open; they do not block this independent process-restriction slice. Apply only eight business Deployments and dedicated accounts, with sequential rollout and a scoped rollback. Full M3 acceptance still requires all M2 compatibility and other hardening tasks.

SL-T07c follows [support-workloads.md](contracts/support-workloads.md): six stateless supporting services plus direct-Pod coverage for the protected app labels/identities. Stateful storage and namespace-wide enforcement remain separate SL-T07b work.

SL-T07d implements [database-storage.md](contracts/database-storage.md) before remaining stateful hardening: quiesce writers, private backup/fingerprints, PVC migration, restore and restart proof, then resume trading. This does not grant SQL least privilege or establish cluster-loss recovery.

SL-T07e implements [collector-boundary.md](contracts/collector-boundary.md): separate infrastructure namespace with a tightly constrained collector exception, then application namespace Baseline v1.35. SL-T07f subsequently preserves the four observability stores and upgrades to Restricted admission.

SL-T07f follows [observability-storage.md](contracts/observability-storage.md): four per-service filesystem checkpoints, verified PVC copies, historical API checks, restricted processes, then application-wide Restricted v1.35. The collector remains separately constrained.

SL-T09 follows [database-permissions.md](contracts/database-permissions.md), with four distinct runtime identities and no runtime DDL. The account/position/processor/matcher grant matrix and position-service runtime rotation have passed live positive/negative and trading verification.

Temporary away-from-desk access follows [remote-console.md](contracts/remote-console.md); only the console is tunneled.

NATS work follows [nats-authorization.md](contracts/nats-authorization.md). First prove bounded broker permissions; live integration requires credential hooks, subject compatibility and trusted browser identity.

Identity work follows [identity-authorization.md](contracts/identity-authorization.md). Provider/token compatibility, route ownership and short-lived browser broker credentials remain acceptance gates; console login is not end-user identity.

The [learning progression](progression.md) is generated from progression.json. Finish baseline acceptance before crediting [residual-risk experiments](contracts/residual-risk.md) as hardened-profile results. RR-01 is the initial canary; known CVEs and OSERA remain a separately specified branch.

The first identity compatibility slice follows [identity-fixture.md](contracts/identity-fixture.md): a disposable TLS provider, actual code/PKCE login and a representative verifier. Spring API enforcement, provider durability, key rotation and browser session behavior remain independent acceptance gates.

Resource-aware local execution follows [resource-modes.md](contracts/resource-modes.md). Guards cover the identity fixture, console and three lab image builders; full C3 service-budget measurement remains separate.

The next resource slice integrates console/build admission and verifies the [minimal account development composition](contracts/account-development.md) with fresh synthetic reset cycles. Full C3 resource budgets remain unmeasured.

The opt-in account candidate follows [account-enforcement.md](contracts/account-enforcement.md):
render from pinned C3, build/test with bounded Java resources, then exercise the
actual Spring API using an isolated signer and independent SQL observation. This
is a local enforcement checkpoint; real-provider token integration, browser flows,
key lifecycle, other APIs and full trading acceptance remain subsequent gates.

SL-T08-account-provider reuses the pinned disposable OIDC provider with
`verify_identity.py --sequential --account-api`. Install its TLS-verified public
key in the candidate's finite trust snapshot, restart only the account process,
and exercise real issued tokens. Repeat with a newly generated issuer key and
prove a still-unexpired token from the retired key is rejected. Keep authoritative
SQL observation outside the application. Explicit offline-token behavior is an
acceptance result, not an immediate revocation claim. No full cluster starts.

SL-T08-browser-local follows [browser-session.md](contracts/browser-session.md).
Use a same-origin session backend for the account-only learning page, with tokens
held only in memory. Reuse the pinned provider/API campaign and verify browser-cookie
protocol behavior before claiming manual browser or inherited Angular integration.

SL-T08-browser-persistent keeps the local provider/session server alive under the
operation lock and verifies provider-confirmed switching with one cookie jar.
Actual Chrome acceptance requires trusted localhost TLS; do not bypass the browser
certificate warning. Keep system trust unchanged unless the user authorizes it.
