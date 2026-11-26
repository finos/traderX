# Java private configuration and position image acceptance

S019-06a3b1 establishes the first Java image boundary for State 019. It is an
accepted bounded checkpoint after [41 hosted checks](../evidence/2026-11-26-position-image.json)
passed on 26 November 2026. The later
account, matcher and processor images reuse the reviewed interface only after
their own service-specific tests. This does not activate a Kubernetes workload.

## Requirements

- JIMG-01: Build the protected position/history candidate from pinned C3 using
  `render_read_security.py`. Verify every declared generation input/output before
  compiling, and reject additional undeclared source inputs. Preserve passing Java test counts and JAR/source hashes in a bounded
  build report; refuse changed build inputs, reports or artifacts at packaging.
- JIMG-02: Pin the Linux AMD64 Python materializer base and Java 21 JRE by image
  manifest digest. Copy only the reviewed JRE, exact application JAR, launcher,
  materializer and immutable `SELECT 1;` startup script. No private configuration,
  source checkout, test output or build dependencies belong in the runtime image.
- JIMG-03: Run as UID/GID 10001. Materialize the exact projected inventory into
  same-UID regular 0600 files under a 0700 directory. Reject unknown/duplicate
  JSON keys, foreign paths, unsafe permissions, environment overrides and
  property/interpolation injection. Emit fixed sanitized failures only.
- JIMG-04: Translate private JSON into a same-UID 0600 Spring properties file at
  `/run/private/java/application.properties`. Invoke a fixed absolute Java executable
  and `/app/application.jar`, with that file as the sole application config
  location. Never place passwords, tokens or private-key contents in argv, image
  environment or evidence. Do not inherit an alternate listener/config source.
- JIMG-05: Require HTTPS on `0.0.0.0:18090`, the fixed PKCS12 path, a scoped SQL
  identity, PostgreSQL `verify-full` and the fixed trusted CA path. Limit the
  connection pool to two. Force bounded verified database initialization before
  successful application startup using only the immutable `SELECT 1;` script;
  there are no migrations or write grants in this startup check.
- JIMG-06: Verify actual exported OCI bytes, source/interface labels, command and
  loaded immutable identity before running. Image labels alone are insufficient.
  The deployment compiler must require private materialization for this role
  without silently treating every remaining Java/.NET image as accepted.

## Private interface

Projected keys, sorted: `config.json`, `database-ca.pem`,
`entitlements.properties`, `public.pem`, `tls.p12`. Paths are fixed by the
launcher, not selected by JSON. The initial role is `position-service` only.

```json
{
  "version": 1,
  "role": "position-service",
  "database": {
    "host": "database",
    "port": 5432,
    "name": "traderx",
    "username": "position_service",
    "password": "GENERATE_PRIVATE_VALUE_AT_RUNTIME"
  },
  "identity": {
    "issuer": "https://identity.example.test/realms/security-lab",
    "audience": "traderx-api",
    "key_not_after": "2030-01-01T00:00:00Z"
  },
  "tls": {
    "password": "GENERATE_PRIVATE_VALUE_AT_RUNTIME"
  }
}
```

The example shows shape, not deployable credentials or a recommended trust
expiry. Generate secrets and a current bounded trust snapshot during provisioning.
Database host/username are validated identifiers; passwords are bounded URL-safe
values. Issuer is an absolute HTTPS URI without userinfo, query or fragment.
Trust expiry must be a future UTC timestamp within eight hours. Public key and entitlement formats
remain those enforced by the existing protected position application.

## Hosted acceptance

Build and test only on a disposable Linux runner. Bind the actual position image
to an owned internal network and the existing TLS database fixture. Issue
synthetic signed tokens against an explicit private entitlement snapshot; run
the actual compiled position/history HTTP APIs. This is not a Keycloak login or
browser campaign. The shared peer fixture's NATS broker is unused in this gate.

Required observations:

1. Valid scoped reads return only the authorized account and cross-account reads
   are denied. Anonymous, malformed/invalid-signature, foreign issuer/audience
   and expired tokens are rejected. Operator-only health/metrics boundaries stay
   distinct from ordinary application reads.
2. HTTPS verifies the actual certificate hostname/CA. A direct probe of the owned
   internal address retains the service's TLS hostname; no public/host port or
   gateway-bypass protection is inferred from that probe.
3. Independent PostgreSQL observations show at least one connection for the
   scoped runtime role and every such connection encrypted. Bad database trust
   causes nonzero startup failure, no successful application listener and no
   business-table mutation; a polling timeout alone does not establish rejection.
4. Actual process/mount evidence verifies UID/GID, dropped capabilities, no
   privilege escalation, read-only root, private file modes and bounded writable
   tmpfs. The initial hosted budget is 768 MiB, 128 PIDs and a 64 MiB temporary
   directory, with explicit bounded JVM heap/metaspace.
5. Retain only sanitized evidence with source/JAR/image hashes, check identifiers
   and outcomes. Remove owned processes, containers, private files and network
   on success and failure. Cleanup failure prevents acceptance.

Remaining Java roles, the separate .NET adapter, support-service composition,
image signatures, CNI/gateway enforcement and the complete learner journey stay
open under the [integrated acceptance contract](integrated-acceptance.md).

The Python base plus Temurin JRE composition is headless only and requires the
hosted startup, HTTPS and SQL checks to pass. Packaged JAR, launcher and startup
SQL bytes are checked against verified build inputs; this is not an image signing
or general supply-chain provenance claim. Public-key trust is a finite snapshot,
not issuer provisioning or rotation acceptance.

## Remaining Java role plan (not implemented by this checkpoint)

Account and processor packaging may proceed independently; matcher follows its
identity, processor and broker dependencies. Every role needs its own actual
image acceptance, even where it reuses the position launcher's private-file code.

| Role | Required interface differences | Acceptance and known integration work |
| --- | --- | --- |
| Account | HTTPS 18088, `traderx-api` audience, scoped account SQL role, same five private keys | Compare real reads to SQL; deny foreign-account and write requests. Remove or explicitly neutralize the inherited unused `PeopleValidationService` URL dependency without enabling account-to-people access. |
| Processor | HTTPS 18091, `traderx-execution` audience, exact matcher subject; no user entitlement file | Preserve disabled legacy controllers/subscribers. Authenticated internal settlement occurs once; wrong subject/audience, arbitrary bodies and legacy routes leave data unchanged. Requires bootstrap and execution migrations. |
| Matcher | HTTPS 18110, user entitlements plus private service-client/broker secrets and outbound truststore | Position's PostgreSQL CA does not configure JVM HTTPS/NATS trust. Provision the identity client, processor and authenticated TLS broker; verify price-to-order-to-settlement/outbox, cancellation, retry and invalid credential/certificate cases. |

Matcher must explicitly disable seed orders and legacy anonymous trade/price URL
behavior, keep Hibernate schema mutation disabled, and use bounded polling and
fixed HTTPS/TLS destinations. Static trust snapshots and future truststore
rotation remain explicit limits. These requirements do not establish Kubernetes
network-policy enforcement or activate the staged deployment.
