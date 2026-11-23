# NATS authorization and browser messaging

Status: isolated fixture and console verified (SL-T10a); live cutover remains planned. SL-T10. C3 broker remains unauthenticated until
client compatibility, transport and subject migration gates pass.

## Pinned-source findings

- trade-service publishes /trades; trade-processor subscribes to /trades and emits
  `/accounts/{accountId}/trades` and `/accounts/{accountId}/positions` after SQL commit.
- order-matcher subscribes to pricing.* and publishes /orders plus
  `/accounts/{accountId}/orders.` price-publisher emits `pricing.{ticker}.`
- Angular connects through /nats-ws and subscribes to account-specific subjects,
  pricing.* and (in all-account/admin views) /orders. Its currently selected account
  is a UI choice, not trustworthy authorization context.
- Sampled Java publishers and Node price-publisher construct connections without
  dedicated client credentials. All publisher/subscriber connections, browser and
  API explorer adapters, readiness probes and smoke tools need review before cutover.
- Slash-separated account subjects are single NATS tokens. `/accounts/*/trades`
  must not be treated as an account wildcard. NATS token boundaries are dots.
  See [official subject rules](https://github.com/nats-io/nats.docs/blob/master/nats-concepts/subjects.md)
  and [publish/subscribe authorization](https://docs.nats.io/learn/security/authorization).

## Staging and compatibility decision

1. SL-T10a: add an isolated authenticated broker fixture, initially with exact legacy
   subject allowlists for two fixed synthetic accounts. Verify permissions over TCP
   and WebSocket and preserve the ordinary C3 broker unchanged. This is an explicitly
   bounded broker demonstration, not live C3 authorization or user-identity proof.
2. SL-T10b: add opt-in credential hooks to canonical generation inputs and every
   reviewed client connection. Rebuild and pin the affected images. Credentials
   never appear in URLs, logs, image layers or browser bundles. TLS trust, reconnect
   behavior and browser credential lifetime are part of the compatibility gate.
3. SL-T10c: for dynamic live accounts, use a profile-scoped transport adapter with
   dot-token subjects (proposed below), preserving external API/event payloads and
   earlier states. Do not silently rename subjects or dual-publish during cutover.
   Specify all producer/consumer adapters, admission pins and a coordinated switch;
   verify no missed/duplicate settlement. An exact-subject alternative requires an
   explicit lifecycle for every newly created account; broad `>` is not a fallback.
4. SL-T10d: integrate trusted identity-to-account authorization from SL-T08 before
   claiming per-user subscription isolation. Short-lived browser credentials must be
   issued from verified identity/ownership; a caller-supplied account ID is not enough.

| Legacy application topic | Proposed profile transport subject |
| --- | --- |
| /trades | traderx.commands.trades |
| /orders | traderx.operator.orders |
| `/accounts/{id}/trades` | `traderx.accounts.{id}.trades` |
| `/accounts/{id}/positions` | `traderx.accounts.{id}.positions` |
| `/accounts/{id}/orders` | `traderx.accounts.{id}.orders` |
| `pricing.{ticker}` | `pricing.{ticker}` (unchanged) |

Account identifiers and tickers must be validated as single tokens. Reject dots,
wildcards and unexpected characters; do not allow topic injection. Proposed subject
names are not active yet and need cumulative contract/conformance updates.

## Permission boundaries

- Browser account identity: no publication permissions; subscribe to pricing.* and
  only its authorized account's three exact event subjects. No /trades or global
  order feed. Ordinary account users do not inherit operator all-account permissions.
- Price publisher: publish pricing.* only; no unneeded subscriptions.
- Trade API: publish trade commands only; no account-event publication rights.
- Trade processor: subscribe to trade commands; publish account trades/positions only.
- Order matcher: subscribe to pricing.*; publish account orders/operator order feed.
- Operator: explicit read-only observation identity; no implicit unrestricted broker
  administrator credentials. Add inbox/reply rights only for demonstrated requests.

NATS permissions are separate publish/subscribe allowlists. Authentication alone
is insufficient; an omitted permissions block must never produce an unrestricted
client. Verify negative behavior directly against the pinned broker version.

## Acceptance and evidence

Unauthenticated/invalid-credential connections fail. A permitted price subscription
receives a unique synthetic message; browser publication of an execution/trade
command fails with an attributable broker authorization error and no subscriber
receipt. Cross-account subscriptions and service subject violations fail. Positive
controls must exercise both transport paths, reconnects and intended permissions.
A successful WebSocket handshake does not establish message authorization.

Correlate scenario/run, client identity, transport, exact subject, broker denial and
independent delivery/outcome. Flush/wait for processing before claiming no effect.
Never publish attack-like commands into the live trading broker. Reset fixture data
and remove temporary clients/containers. Keep monitoring/operator endpoints behind
a separate authenticated boundary; no direct alternative route may bypass it.

Live cutover requires full trading plus broker authorization checks, new-account
behavior, reconnects and credential expiry/revocation. Do not silently weaken TLS,
restore anonymous access, or grant broad wildcards to make a positive test pass.

## SL-T10a implementation contract

Use the pinned C3 NATS image in a dedicated labelled Docker fixture, never the live
broker. Bind only 127.0.0.1 ports 18444 (TLS-first NATS) and 18445 (WSS); do not
expose monitoring. Non-root, read-only root, no capabilities/escalation, bounded
resources and a private fixture network. No JetStream or trading consumers.

Generate per-run credentials and a short-lived localhost test certificate beneath
a private runtime directory; no credential URLs or unredacted configuration/logs
in evidence. Verify certificate trust and hostname on both transports. Temporary
files and the owned container/network are removed in finally. Refuse unrelated
objects with colliding names. The fixture network is separate from C3; no C3-wide
network-policy or egress-isolation claim is made.

Test TCP and WSS separately: anonymous/wrong credentials, price delivery, each
browser's own-account delivery, cross-account subscription rejection, browser
command publication rejection, inappropriate service publication/subscription,
permitted service command/event delivery and reconnect. Every delivery uses a unique
run marker. Confirm denied publications never reach an independent authorized
observer, with broker flush barriers and a bounded observation interval. Record
actual broker permission errors; a timeout alone is not rejection evidence.

The browser identity is a synthetic broker credential exercised over WebSocket by
a protocol client; no claim of OIDC login, browser token issuance or live UI account
isolation. The new console card must explain this distinction before running.

## SL-T10b staged client compatibility

First add optional server-side credential hooks to the canonical price-publisher
source template. With no security settings, preserve its existing connection options.
Setting any of NATS_SECURITY_REQUIRED, NATS_USER_FILE, NATS_PASSWORD_FILE or
NATS_CA_FILE activates strict validation: required=true, a complete set of absolute
readable nonempty files, and a credential-free explicit tls:// NATS_ADDRESS. Reject
partial settings and URL credentials before making a connection. Use TLS-first and
verified server certificates; never add an insecure fallback. Credentials are read
from projected Secret files at startup; rotation requires a rollout until explicit
hot-reload/reconnect behavior is designed. Do not log client options or credential
file contents. Standard TLS hostname verification remains enabled.

Verify legacy startup, configuration failure cases and real Node NATS client TLS
handshake/authentication before rebuilding its image. This stage alone neither
completes all client hooks nor authorizes live broker cutover. Java publishers,
subscriber, matcher, UI, API explorer and readiness/smoke clients remain gates.

### Remaining client coverage before live cutover

| Client | Canonical source | Remaining gate |
| --- | --- | --- |
| Trade API publisher | State 006 runtime override, trade-service NatsJSONPublisher | Secret-file credentials and verified TLS; publish-only acceptance |
| Processor publisher/subscriber | State 006 runtime overrides, trade-processor NatsJSONPublisher and NatsJSONSubscriber | Both connections use scoped identity; settlement/reconnect checks |
| Matcher publisher/pricing subscriber | State 009 runtime overrides, NatsJSONPublisher and PricingNatsSubscriberService | Compatible credentials/TLS on both paths; generator fallback remains consistent |
| Price publisher | state-010-pricing-awareness-market-data-overlay/price-publisher | Source credential hook verified; image rebuild/digest pin and deployment still pending |
| Browser adapter | State 006 web-front-end trade-feed.service.ts | Verified user/account identity, short-lived credential issuance and revocation; never embed a service secret |
| API explorer | pipeline/install-generated-api-explorer.sh | Explicit authenticated operator/user scope, no anonymous bypass |
| Probes and smoke clients | Generated readiness and inherited messaging smoke assets | Authenticated positive control and no secrets in process arguments/logs |

Do not credit isolated fixture reconnects as reconnect verification for each application
client. Final compatibility requires application-specific restart/reconnect and
credential-rotation checks before enabling broker authentication.

### Java credential/TLS contract

One canonical `NatsSecurity.java` helper under State 006 generation inputs is
installed by the State 006 renderer into trade-service/trade-processor and the
State 009 renderer into order-matcher. All five connection sites use it, including
the matcher renderer fallback. Earlier states keep anonymous defaults when no
security settings are present. The same four NATS security variables used by the
Node publisher activate strict validation; the effective Java nats.address must
be tls:// with no URL credentials, query, fragment or path. Secret files are read
at startup; no automatic rotation or reconnect reload is claimed.

The CA file populates a dedicated trust store. TLS-first and preservation of the
configured DNS name are required. The pinned JNATS socket transport does not
explicitly set endpoint identification, so an extended trust-manager adapter sets
HTTPS endpoint identification before delegating server validation to the JDK trust
manager. Context-free server validation is rejected. Never replace this with a
trust-all manager or disable hostname checking. Verify trusted/wrong-hostname and
untrusted-CA failures separately from broker authentication failure.

Helper/protocol validation and service compilation do not establish Spring
application lifecycle, settlement, reconnect or rotation compatibility. Keep
SL-T10b-java and image deployment open until those acceptance checks pass.

### Price publisher lifecycle acceptance

In the disposable broker only, prove that the same publisher process resumes
fresh price delivery after a broker restart with unchanged credentials. Then rotate
only its broker password and restart the fixture to invalidate every connection.
A fresh connection with the retired password must receive an explicit authentication
denial. Update the projected password file and replace the publisher process; fresh
price delivery must resume with the new credential. Do not infer hot reload from a
file update or credit old buffered messages as post-rotation success. Preserve
observer identity and all broker permissions. Record process replacement, outcomes
and limitations without passwords. This test does not establish Spring application
reconnect/rotation, live C3 settlement or uninterrupted delivery during outage.

### Local price-publisher candidate image

For the initial source-only change, derive a candidate from the pinned C3
price-publisher image, replace only the reviewed canonical runtime JavaScript,
and retain its existing dependency/OS layers. Require the template dependency lock
to match the pinned snapshot before using this method; changed dependencies require
a full rebuild. Record base manifest digest, source/lock hashes, platform and local
image config ID. The local config ID is not a registry manifest digest or signature.
No push, image admission update or live rollout is implied. Verify source bytes and
non-root image defaults before running authenticated fixture tests.


The attempted source-only candidate was rejected because the canonical dependency
lock differs from the C3 snapshot (including yahoo-finance2 2.14.0 → 2.14.2).
Therefore the implemented builder uses generation/price-publisher.Dockerfile:
pinned Node base, complete npm-ci lock resolution with install scripts disabled,
and canonical source/data. No unpinned apk upgrade runs during this candidate build.
Record the Dockerfile hash and lock hash; a separate vulnerability assessment remains
required. The earlier source-only method is not used for this candidate.

### Java application-adapter lifecycle acceptance

Exercise each of the five actual generated messaging classes against the isolated
broker: three NatsJSONPublisher instances, processor NatsJSONSubscriber and matcher
PricingNatsSubscriberService. Use each service's resolved Gradle classpath and
canonical source overrides. Before and after broker restart, require unique payload
receipt through the same adapter process. Rotate its credential by changing the
fixture configuration and restarting the broker; verify explicit retired-login
denial, update its private Secret file, replace the process and require new receipt.

The matcher callback is a mock domain service: this proves its real message parsing
and dispatch, not database-backed matching or trade settlement. Processor callbacks
also record markers rather than execute business writes. Record these limits and
leave full Spring/C3 settlement acceptance open. Verify disconnected status cannot
be misclassified as connected by substring matching.

### Java candidate packaging gate

After all five adapter lifecycle cases pass, package each compiled Spring bootJar
using generation/java-client.Dockerfile and the pinned Java 21 JRE base. Reject
canonical source drift and any packaged bytecode mismatch. Record JAR/source hashes,
base digest, local image config IDs and lifecycle run ID. Run the container as UID
10001 with read-only filesystem and dropped capabilities to verify the JAR hash and
Java runtime startup. These are packaging checks; full Spring startup, database
configuration, settlement, signing/admission and rollout are separate gates. No
registry push or live deployment is performed by the candidate builder.

### Full C3 candidate compatibility rollout

After adapter lifecycle and candidate packaging gates, import the four local images
into only the named lab kind node. Verify imported manifest config digests against
the recorded local image config IDs, then reference the imported images by manifest
digest. This is local pinning, not registry publication or signed image admission.

Serialize against console experiments. Save current images/pull policies privately;
patch only those fields with resource-version preconditions. Preserve SQL Secrets,
PVCs, resources, namespace admission, security contexts and all other deployment
settings. Roll out sequentially; require fresh Pods, full readiness, unchanged
non-image settings, workload/security verification and the inherited full trading
smoke suite. Keep current NATS anonymous behavior for this compatibility gate;
Secret mounts, broker authentication and trusted browser identity remain separate.

On failure, restore touched images/pull policies in reverse order and verify
readiness without overwriting concurrent unrelated edits. Persist success/failure,
rollback outcome and exact before/after image pins. Active candidate pins form an
explicit runtime overlay consumed by workload reapply and verification; never edit
the immutable reference snapshot or silently accept arbitrary live images.
