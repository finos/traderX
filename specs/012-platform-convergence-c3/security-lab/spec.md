# TraderX Security Lab specification

Status: experimental profile of C3; no new catalog state. Created 2026-11-22.

## Users and scenarios

Contributors reproduce security boundaries while trading remains functional.
Evaluators compare a candidate runtime product with an already hardened baseline.
Operators reset synthetic data and retain evidence outside the tested application.

1. An outsider encounters only the approved application gateway; operator routes and direct backends are inaccessible.
2. A read-only user cannot trade; a trader can trade only on assigned accounts; an operator has separately authenticated administrative access.
3. An assumed-compromised service is denied unrelated network, broker, database and cluster operations.
4. A service attempts a synthetic write within its database grants but outside the user's authorization. Record the actual resulting state, including delayed downstream effects, without presuming any runtime engine prevents it.
5. Reset restores the canary and ordinary trading; an independent collector retains the correlated run evidence.

## Functional requirements

- SL-FR-01: Pin generated snapshot SHA, its recorded canonical source SHA, profile source SHA, image digests and configuration hashes. Missing pins prevent a reproducibility claim.
- SL-FR-02: Inventory routes, workload identities, database identities, subjects and directed service flows with source references. Static observations are not runtime findings.
- SL-FR-03: Generate a separate profile; preserve reference C3. Apply TLS/WAF, application authorization, restricted workloads, admission, enforced network segmentation, scoped database/broker credentials and external evidence collection in staged changes.
- SL-FR-04: Compare reference, hardened observation, open-source enforcement and candidate profiles. Optional combined protection is a fifth profile. Change only WAF mode for disabled/detect/block comparisons.
- SL-FR-05: Every negative scenario has a positive control and names its expected intervening layer. An alert, HTTP response or process kill alone cannot prove prevention.
- SL-FR-06: Assumed-compromise fixtures use designated synthetic records, bounded actions and explicit opt-in; they establish no real RCE or WAF bypass claim.
- SL-FR-07: Record independent before/after state, settled asynchronous effects, application receipt, attributed decisions, normal-workflow health and recovery. Unknown is a first-class outcome.
- SL-FR-08: CCC mappings include version, assessment requirement, implementation, test, evidence, result and limitation. Unverified mappings and local approximations carry no compliance claim.
- SL-FR-09: Candidate installation requires documented language/runtime/kernel/architecture support, privilege requirements, hooks, protection claim, failure mode and rule/training disclosure.
- SL-FR-10: Generate reviewable policy artifacts without modifying a Kubernetes context. Deployment commands must explicitly identify an isolated lab cluster and namespace.
- SL-FR-11: Provide a local hands-on experiment console following [the console contract](contracts/console.md), with bounded scenario execution, evidence and honest readiness status.

- SL-FR-12: Provide an optional isolated CVE remediation exercise following [the CVE and OSERA contract](contracts/cve-patch-analysis.md), with pinned vulnerable/fixed artifacts and independently verified patch outcomes.
- SL-FR-13: Teach and assess the [Security Lab learning objectives](learning-objectives.md); preserve equivalent tests for a separate CALM follow-on state.

- SL-FR-14: Present evidence-linked learning checkpoints in a generated Mermaid progression, with explicit verified, isolated-fixture, next and planned status. Phase navigation and reset remain separate implementation gates.
- SL-FR-15: Test residual authority under verified controls using [bounded residual-risk scenarios](contracts/residual-risk.md); distinguish assumed compromise from verified exploitation and measure independent resulting state.

- SL-FR-16: Provide explicit local operating modes and bounded, read-only resource preflight; distinguish capacity rejection from security results and document enforcement scope.

## Nonfunctional requirements

- SL-NFR-01: Preserve C3 APIs and event contracts; subject changes require a cumulative subject map and migration plan.
- SL-NFR-02: Secrets never enter generated ordinary configuration, source control, evidence or browser bundles. Separate runtime and bootstrap identities.
- SL-NFR-03: No production data or public attack targets. Infrastructure agents have separately scoped privileges; application pods remain restricted.
- SL-NFR-04: Measure p95/p99 latency, throughput, CPU/memory, alert delay and recovery under a fixed workload; test bursts, reconnects, bulk operations and upgrades. Report sample size and duration, with no invented performance threshold.
- SL-NFR-05: Generated artifacts are deterministic and derived from canonical profile inputs. Offline policy validation never counts as enforcement verification.

## Acceptance and edge cases

The first release is accepted only when normal trading and every selected negative check run against a pinned deployment, reset works twice, and an independently collected scorecard explains outcomes and limitations. A missing CNI, unreachable target, absent telemetry, failed positive control, unsettled queue, incomplete image pin, or unavailable runtime hook yields inconclusive/blocked rather than passed. Detection after a write is detection with impact, not prevention.

Managed cloud identity, KMS, zonal resilience, cluster-admin/kernel compromise, Radius, FDC3 and additional runtime engines are deferred. Supplier evaluation is blocked until its integration contract is supplied. The current implementation includes a verified reference baseline, initial live network/admission/WAF fixtures, restricted workload processes, persistent data stores and application-wide Restricted admission, not the accepted hardened first release. CALM-driven security is a separate planned follow-on state, with its number undecided and no dependency for completing this security profile.

### Account authorization development slice

Implement FR-03 identity checks first through the opt-in candidate described in
[account-enforcement.md](contracts/account-enforcement.md). A valid signed token
must not grant access to accounts outside the server-owned entitlement map;
filtered lists and detail reads must agree. Deny account and membership mutations
for every supplied user role until provisioning is separately specified. Invalid
tokens must fail authentication, and denied operations must leave synthetic rows
and sequence state unchanged. Repeat after reset. Local test-signer results do not
satisfy real-provider, browser, full-C3 or trading integration acceptance.
