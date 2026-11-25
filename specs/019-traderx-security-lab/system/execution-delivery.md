# Background execution delivery contract

Status: PostgreSQL reservation/settlement and the processor HTTP boundary are
validated in isolated fixtures; matcher dispatch and broker integration remain
unimplemented. No runtime cutover is claimed. This refines S019-04b2.

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

Apply once under a bootstrap transaction to the pinned C3 schema. Reapplication
refuses rather than silently accepting drift. They are not part of deployed
bootstrap yet. Existing runtime credentials do not receive schema-change rights.
No application should combine this settlement function with the old Java booking
path for the same execution. That would double-book independently of receipts.

## Remaining integration

- Persist the UUID and reservation from the matcher and send only through an
  authenticated execution route with its own audience and exact service subject.
- Verify current accepted authority before dispatch; define policy snapshot
  reload/revocation behavior. A database receipt does not replace authentication.
- Replace the candidate processor booking path with receipt-backed settlement;
  propagate the same UUID through the broker. Legacy messages must not fall back
  to ordinary booking when the execution contract is required.
- Use durable broker delivery or a retrying outbox. Broker acknowledgments and
  HTTP success do not prove a trade settled; poll the authoritative receipt.
- Add a transactional event outbox for post-commit trade/position notifications.
  The current after-commit publisher can lose notifications on process failure.
- Integrate cancellation under database locking. If settlement commits first,
  cancellation must preserve the fill; if cancellation commits first, unsettled
  execution must be rejected. Existing Java cancellation is not yet adapted.
- Test sell/flat/new-position pricing, service restart, expired initiating token,
  revoked authority, forged service identity, broker replay and ambiguous HTTP
  response against independent database observations in the integrated stack.

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
impersonate an expired user. The matcher dispatch adapter and its service-token
acquisition are still required. The old trade-service user route continues to be
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

The client is compiled into the matcher candidate but not yet connected to the
scheduler or enabled by a Spring bean. Tests use a controlled transport/clock and
mock HTTPS connection to verify form encoding, refresh, failure redaction,
redirect rejection and response bounds. They do not prove a live Keycloak grant
or deployment certificate trust. The next integration still needs matcher
reservation/retry, token acquisition configuration, dispatch and receipt
reconciliation without a second local fill.
