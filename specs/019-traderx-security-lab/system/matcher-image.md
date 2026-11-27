# Matcher image, service identity and outbound TLS

S019-06a3b2c extends the accepted account/processor image checkpoints. This
contract requires the actual protected matcher and processor OCI images, owned
TLS peers, and independent settled database outcomes. Implementation and source
tests alone do not accept this milestone or activate Kubernetes.

## Runtime requirements

- MIMG-01: Build canonical protected matcher source from pinned C3; require its
  authorization, accepted-order authority, service-token and broker tests to pass.
  Bind the exact bootJar, required classes, source/build reports, OCI bytes and
  loaded immutable image identity. Preserve existing Java-role interfaces.
- MIMG-02: Fix HTTPS to 18110 with user audience `traderx-api`, explicit finite
  signing-key trust and private subject/account entitlements. Runtime database
  access uses the scoped matcher login with PostgreSQL `verify-full`. Bootstrap
  and migrations belong to the fixture provisioner, not application startup.
- MIMG-03: Fix processor execution to HTTPS `/internal/executions/`; bind the
  client-credentials token endpoint to the configured issuer. Keep service-client
  and broker secrets in separate owner-private files. No private password,
  private-key bytes or bearer token may appear in argv, environment or evidence.
- MIMG-04: Validate processor, issuer and broker certificate chains and hostnames
  using explicit outbound trust. PostgreSQL's CA file does not configure these
  other transports. A runtime-generated truststore may contain public CA
  certificates only and use a documented nonsecret integrity password; it must
  not contain private keys. Tool arguments, aliases and paths are fixed.
- MIMG-05: Disable seed orders and inherited anonymous trade/price destinations.
  Explicitly configure bounded matching intervals, Hibernate physical naming,
  disabled schema mutation and open-in-view, and required TLS broker settings.
  Run non-root with read-only root, dropped capabilities, private writable
  directories, bounded JVM/PIDs/storage and no privilege escalation.

The proposed projected inventory has ten fixed keys: `broker-ca.pem`,
`broker-secret`, `client-secret`, `config.json`, `database-ca.pem`,
`entitlements.properties`, `identity-ca.pem`, `processor-ca.pem`, `public.pem`,
`tls.p12`. The private JSON selects `order-matcher` and validates exact database,
identity, TLS, execution and broker schemas. It cannot select commands, arbitrary
file paths, redirects or alternative plaintext listeners.

## Owned peer boundary

Use the pinned PostgreSQL/NATS fixture with explicitly scoped extra identities.
Matcher subscribes to required price subjects and may publish only its required
account-scoped order-status update. The execution-enabled source still emits
that order update; it must not gain settlement-topic or broker-administration
publication. A separate synthetic price publisher/observer owns no application
business authority. Preserve the existing worker-fixture default permissions.

The initial image campaign may use a synthetic HTTPS OAuth peer bound only to
its verified owned Docker bridge gateway. It authenticates the exact client ID
and secret and issues finite RS256 tokens with the processor audience and exact
matcher subject. Reject duplicate/unknown form fields, oversized/slow requests,
wrong paths and credentials. Suppress raw request logs and return only bounded,
sanitary counters to the campaign. Do not bind the peer to every host interface.

This peer is deliberately not Keycloak. It verifies the image's actual HTTPS
client-credentials transport and service-token use, not live issuer provisioning,
provider sessions, discovery, key rotation, availability or federation. Existing
real-Keycloak browser/trading regression remains a separate proof; support-service
composition stays under S019-06a3b4.

## Required live outcomes

1. Actual images bind to the owned private network with inspected immutable IDs.
   HTTPS, private materialization, generated truststore, process restrictions and
   scoped encrypted SQL connections are observed rather than inferred from YAML.
2. An authorized HTTP order and authenticated TLS price notification cause an
   actual matcher reservation, authenticated HTTPS processor settlement and the
   expected authoritative trade/position/order/receipt plus two outbox rows.
   Observe the expected order-status update separately; a broker publication or
   HTTP success alone is not proof of settlement.
3. User identity and account-scope denials leave business state unchanged.
   Cancellation, duplicate delivery and actual image restart preserve durable
   outcomes. Unrelated business rows/reservations remain unchanged except for the
   explicitly designated synthetic test actions.
4. Incorrect service credentials produce an attributable OAuth rejection and no
   settlement. An accepted order/reservation may legitimately remain pending
   because reservation precedes token acquisition. Recovery must reuse its
   durable execution identity rather than create duplicate settlement effects.
5. Incorrect broker password, CA and hostname are rejected at their actual
   authentication/TLS boundary, with no settlement or downstream effect. A timeout
   without an attributable rejection is incomplete, not a successful denial.
6. Matcher credentials cannot publish to an unapproved settlement subject or
   gain administrative broker access. Check explicit broker rejection and the
   authoritative result, not merely a missing notification.
7. Collect only sanitized configuration/source/image identifiers, counters and
   outcomes. Remove owned processes, containers, networks and private materials
   on success and failure; cleanup failure prevents acceptance.

A passing image campaign does not close CNI enforcement, gateway/WAF coverage,
signed-image admission, external evidence retention, credential/trust rotation,
the .NET image, cumulative deployment or the full learner journey. Keep those
limits visible in the [completion roadmap](completion-roadmap.md).

## Accepted bounded checkpoint — 27 November 2026

[46 actual-image checks](../evidence/2026-11-27-matcher-image.json) pass at
`27e5e927`. The [full eleven-job hosted run](https://github.com/finos/traderX/actions/runs/45944446218)
also passes, including 474 source tests and existing browser, trading, delivery,
directory, image and admission regressions. One pending reservation survives
incorrect service credentials and an actual matcher-image restart; corrected
credentials produce one settlement/receipt and two outbox rows. Fill and
cancellation notifications are independently observed in the canonical scoped
NATS envelope. Unrelated business rows and ledger state remain unchanged.

The runner builds both Java artifacts before starting BuildKit, retaining the
idle-runner resource guard. TLS rejection attribution handles the broker client's
wrapped IOException only with explicit TLS evidence and terminal non-OOM failure;
timeouts and configuration errors do not count. None of these results closes the
remaining acceptance boundaries above.
