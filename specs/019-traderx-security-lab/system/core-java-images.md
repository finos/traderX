# Account and execution image acceptance

This extends the accepted [position image](java-runtime.md) under S019-06a3b2.
Account and processor are independent image checkpoints; matcher remains a later
checkpoint with identity-client and outbound HTTPS/NATS trust prerequisites.
None activates the staged Kubernetes deployment or closes cumulative acceptance.

## Common requirements

- CJIMG-01: Build each canonical protected service from the pinned C3 snapshot in
  an isolated hosted workspace. Verify its complete declared generation inputs,
  required passing Java authorization tests, exact bootJar and bounded build
  report before packaging. Reject undeclared source inputs and artifact drift.
- CJIMG-02: Reuse pinned Linux AMD64 Python/Java runtime bases and private-file
  materialization. Verify actual OCI application bytes, parent traversal modes,
  UID/GID, command, source/interface labels and loaded immutable identity.
- CJIMG-03: Retain read-only root, UID/GID 10001, dropped capabilities, no privilege
  escalation, bounded JVM and temporary storage, owner-private configuration and
  sanitized diagnostics. Configuration cannot select arbitrary paths or commands.
- CJIMG-04: Require fixed HTTPS listeners and PostgreSQL `verify-full` using a
  private trusted CA and scoped service login. Force only immutable `SELECT 1;`
  startup checks; do not perform migrations through application runtime identities.
  A wrong database CA must terminate startup without serving HTTP or changing
  business data. Polling timeout alone is not proof of rejection.
- CJIMG-05: Check server certificate CA/hostname verification and independent
  database observations showing every runtime connection encrypted. Fixture JWTs
  prove API verification against explicit static trust, not live issuer rotation.
  Collect authoritative SQL effects and remove only campaign-owned resources.

## Account-service checkpoint: S019-06a3b2a

The fixed listener is HTTPS 18088 with audience `traderx-api`. Its private
inventory matches position: `config.json`, `database-ca.pem`,
`entitlements.properties`, `public.pem`, `tls.p12`; the JSON role must explicitly
select `account-service`. Accounts use their own scoped SQL identity.

The protected candidate permits account reads only. Its inherited unused
people-validation dependency must not require an unconfigured destination or
silently add account-to-directory network access. Remove that unused bean from
the protected canonical renderer while preserving reference C3 and other states.

Required live outcomes:

1. Actual account collection and ID reads match independent SQL and include only
   the caller's permitted accounts; both test accounts have nonempty fixtures.
2. Foreign-account reads and account write/legacy routes are denied. Anonymous,
   malformed, invalid-signature, foreign issuer/audience and expired identities
   fail, and unknown subjects cannot obtain business grants.
3. Operator identity does not imply account access. This account candidate has
   no privileged diagnostics route: both operators and readers must be denied
   those routes. Public liveness remains distinct. No directory call is required.
4. All successful reads and rejected operations leave authoritative data unchanged.
   Transport, startup, process/file restrictions and cleanup satisfy CJIMG-01–05.

## Trade-processor checkpoint: S019-06a3b2b

The fixed listener is HTTPS 18091 with audience `traderx-execution` and an exact
configured matcher subject. Private keys are `config.json`, `database-ca.pem`,
`public.pem`, `tls.p12`; a user entitlement file is not part of this interface.
The processor retains its scoped execution SQL identity. Legacy public execution
controllers and broker subscribers remain disabled in this protected candidate.

Required live outcomes:

1. Bootstrap and execution migrations run under the fixture's provisioning
   identity. Seed bounded orders/reservations separately from the processor.
2. The actual `POST /internal/executions/{id}` accepts only the configured service
   subject/audience and valid bounded request. Independent SQL proves settlement,
   reservation consumption, account/position changes and canonical outbox effects.
3. Wrong subject/audience, malformed/expired/invalid-signature tokens, anonymous
   calls, altered request bodies and legacy routes cause no business mutation.
4. Duplicate delivery and an actual image restart preserve exactly one settlement
   and its expected durable events. A successful HTTP response alone is not proof.
5. Verified HTTPS/SQL, rejected bad CA startup, private runtime restrictions and
   owned cleanup satisfy CJIMG-01–05. No live Keycloak/client rotation claim follows.

## Execution and limits

Each campaign uses a separate disposable hosted runner and owned database fixture;
parallel validation does not share generation targets, containers or credentials.
The `java-core-images` workflow scope is for focused diagnostics; full regression
remains required before recording accepted milestones. Only sanitized JSON
results may be uploaded. Images and synthetic private materials are not published.

Matcher packaging, actual .NET image acceptance, issuer/broker/market-data flows,
network enforcement, signed-image admission and the complete learner journey remain
open. The [completion roadmap](completion-roadmap.md) defines the first release.
