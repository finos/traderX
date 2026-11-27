# Background execution delivery contract

Status: PostgreSQL reservation/settlement and the processor HTTP boundary are
validated in isolated fixtures; opt-in matcher dispatch/cancellation and the SQL
event outbox are component-tested. Broker delivery and deployment integration remain open. No runtime cutover is claimed. This refines S019-04b2.

## Durable boundaries

An execution UUID is allocated once, persisted before sending, and retained across
retries. The reservation function derives account, security, side and accepting
principal from the stored order, rather than accepting them from an execution
caller. Quantity and price are immutable for a UUID. A retry with a conflicting
payload is rejected. An identical retry retrieves the existing identifier; it is
not authorization to publish a new trade.

Reservations serialize on the order row. Aggregate unresolved quantity cannot
exceed remaining quantity; buy/sell limit prices constrain reservations. Unknown,
legacy-without-authority and canceled orders cannot acquire new reservations.
Unresolved reservations are retained conservatively, not timed out and silently
released after an ambiguous send. The metadata remains trusted application state;
a compromised writer that can change both the order and its acceptance metadata
is outside this boundary's protection.

The settlement candidate locks the order and account, reads only persisted
reservation fields, and atomically writes the trade, position, order remainder
and unique execution receipt. A committed receipt makes repeated delivery a
lookup. A rollback removes all four effects. Account locking also serializes
creation of absent position rows. Only the processor identity may invoke
settlement; the matcher cannot acknowledge its own execution. The matcher has
read access and reservation-function execution, but no direct ledger mutation or
DDL privileges. Bootstrap owns migration and the fixed-search-path functions.

These functions are separate, opt-in candidate artifacts:

1. `sql/execution-reservations.sql` adds nullable acceptance columns and ledger.
2. `sql/execution-settlement.sql` adds atomic settlement and receipt authorization.
3. `sql/execution-cancellation.sql` adds cancellation under the same order-row lock.
4. `sql/execution-events.sql` adds the transactional outbox before any settlement.

Apply once under a bootstrap transaction to the pinned C3 schema. Reapplication
refuses rather than silently accepting drift. They are not part of deployed
bootstrap yet. Existing runtime credentials do not receive schema-change rights.
No application should combine this settlement function with the old Java booking
path for the same execution. That would double-book independently of receipts.

## Remaining integration

- Provision and validate the matcher service identity, private credential mount,
  TLS trust and live Keycloak client grant across matcher and processor.
- Install the candidate migrations in fresh bootstrap before execution; keep
  legacy booking disabled during any future cutover.
- Connect the [transactional event outbox](event-delivery.md) to authenticated
  durable broker publication and consumer deduplication. Database acknowledgment
  alone cannot prove broker acceptance or a downstream effect.
- Validate expiry, authority-policy reload/revocation, restart, cancellation,
  ambiguous response and event replay against independent database and broker
  observations in the integrated stack.
- Remove or constrain legacy direct order-write privileges where appropriate;
  the current application gates cannot contain a fully compromised matcher SQL
  writer. Preserve this distinction in the residual-authority exercise.

## Reproduction and evidence

With full clusters and the lightweight browser lab stopped:

```bash
python scripts/security-lab/verify_execution_reservations.py \
  --runtime-dir /absolute/private/runtime --output /absolute/private/result.json
```

The guarded fixture uses the pinned PostgreSQL image, a 256 MiB limit, one CPU,
no host ports, private ephemeral credentials and an owned persistent volume.
It tests concurrent reservations, conflicting retries, real restart, restricted
roles, cancellation, concurrent duplicate settlement and transactional rollback.
It removes its container/volume after completion. Evidence exports no secrets.

This proves the candidate SQL transaction behavior for the recorded synthetic
buy workflow, not authenticated end-to-end trading, broker delivery, live Keycloak
expiry, or a defense against a compromised bootstrap administrator. The live lab
continues to use its previously validated images.

## Processor HTTP candidate (25 November)

The processor candidate exposes `POST /internal/executions/{uuid}` under RS256
issuer/key validation, the dedicated `traderx-execution` audience and an exact
configured matcher subject. User roles and caller headers confer no execution
rights. The request has no account/price/quantity body; the processor invokes
`lab_execution.settle(?)` with a bound UUID and returns the authoritative receipt.
SQL business conflicts return 409; other database failures return 503 without SQL
details. The old `/tradeservice/order` HTTP route is denied and the legacy NATS
trade subscriber is removed from the candidate configuration. Legacy booking,
NATS publisher configuration and message-bus health beans are also unregistered;
the original booking class remains available to its explicit regression tests.

This deliberately tests the processor boundary directly before adding a gateway
relay or broker hop. It does not turn the matcher into a general trader or
impersonate an expired user. The matcher dispatch adapter now exists as an opt-in component candidate; live
identity and deployment wiring remain required. The old trade-service user route continues to be
a separate direct-API candidate and is not rerouted automatically.

`verify_execution_http.py` starts the verified processor jar and a disposable
PostgreSQL instance on random **loopback-only** ports. Unlike the SQL-only fixture,
this explicit integration fixture enables Docker bridge networking and a
127.0.0.1 port mapping; the default SQL fixture remains network-isolated. It uses
synthetic signed tokens and cleartext loopback HTTP, so it does not establish
live Keycloak or deployment TLS acceptance. The runner checks denied identities,
payload overrides, the legacy route, concurrent execution and retries after
processor/database restart against independently queried SQL outcomes. Process,
container and volume cleanup run on failure as well as success.

## Matcher service-token client checkpoint

`ServiceTokenClient` implements the client-credentials acquisition boundary. It
requires a configured HTTPS token endpoint without userinfo/query/fragment, uses
platform TLS verification, refuses redirects, sets connect/read timeouts, and
bounds secret/response reads. It never writes tokens to disk or surfaces response
bodies/credential-bearing exceptions. It accepts only a Bearer compact-JWT token
with an integral lifetime of 1–300 seconds; issuer, signature, audience and subject
remain mandatory checks at the processor endpoint.

Tokens are cached in memory until 30 seconds before the reported expiry, measured
from request start. Refresh rereads the absolute-path secret file; refresh failure
never returns the old cached token. A rotated secret takes effect on refresh, not
instantaneously. Deployment must mount this file privately with the intended
service identity; this class does not provision secrets or Keycloak clients.

The client is connected through the opt-in `MatcherExecution` bean described
below. Token-client tests use controlled transport/clock and mocked HTTPS; they
do not prove a live Keycloak grant or deployment certificate trust.

## Matcher dispatch and cancellation checkpoint

`lab.execution.enabled=true` opts in to the candidate. It requires a fixed HTTPS
processor URL ending in `/internal/executions/`, a token endpoint, client ID and
private secret-file path. Default generation leaves execution disabled.

Before dispatch, the matcher checks stored acceptance terms and the currently
loaded server-side entitlement map. It reuses an unresolved execution UUID or
persists a new reservation before acquiring credentials and sending. Ambiguous
HTTP failures retain the UUID. Only a matching SQL receipt counts as settlement;
HTTP 200 alone cannot cause a local fill. The matcher clears stale JPA state and
reloads the SQL result instead of applying a second fill or saving stale fields.

Pending reservations retry even when the latest market price no longer meets
the limit, or a restarted scheduler has not received a price yet: execution uses
the reservation's previously validated immutable price. New reservations remain
price-gated. Connect/read timeouts bound inactivity, not a total wall-clock
deadline against a continuously trickling peer; production deadline behavior is
still an integration consideration.

Cancellation checks the caller's stored account entitlement and invokes a bound
SQL function that locks the order. It reloads the resulting row without a stale
JPA save. Settlement-first preserves the fill; cancellation-first blocks later
settlement. The independent PostgreSQL campaign observed both lock orders.
This does not remove the matcher role's existing direct UPDATE grant.

Seven dispatch unit tests and four Spring/H2 matcher tests cover UUID reuse,
receipt evidence, token failure, authority revocation, endpoint configuration,
pending retries and fresh-state reload. SQL lock/race evidence is separate from
these mocked-dispatch tests. The combined candidate has 62 passing Java tests;
no live matcher-to-Keycloak-to-processor or deployed trading claim is made.
