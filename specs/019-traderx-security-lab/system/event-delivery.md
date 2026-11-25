# Transactional settlement event outbox

Status: additive SQL candidate validated by 38 real PostgreSQL checks; delivery
adapter and broker integration remain pending. This complements the processor's durable execution receipt.

## Transaction boundary

Install `sql/execution-events.sql` after the reservation/settlement migrations and
before the first execution settles. Installation refuses an existing receipt:
the current position cannot reconstruct a historical position snapshot. There
is no silent backfill and no mutation of an existing deployed environment.

An AFTER INSERT trigger on the receipt stores two immutable snapshots in the
same transaction: a settled trade and the resulting position. If snapshot
creation fails, the entire trade/position/order/receipt transaction rolls back.
Settlement replay finds the existing receipt and creates no further events.

Event IDs are stable: `<execution UUID>:trade` and `<execution UUID>:position`.
Each event includes its execution ID, event kind, account-scoped topic, immutable
payload and a database-generated sequence. Trade payload fields match the
candidate's camel-case public model; position snapshots include quantity and
average cost basis. No credentials or access tokens enter events.

## Delivery and authorization

A separate `lab_event_publisher` NOLOGIN role owns no objects and has no direct
ledger/table mutation rights. A future provisioned login can inherit this role;
bootstrap controls that provisioning. The role can only claim and acknowledge
events through fixed-search-path functions. Matcher and processor logins cannot
claim or acknowledge, and publisher rights cannot reserve or settle trades.

`claim_events(worker UUID, batch size, lease seconds)` accepts batches of 1–100
and leases of 1–300 seconds. Row locks with SKIP LOCKED permit multiple publishers
without assigning the same live lease twice. Each claim gets a fresh random
lease token. The publisher commits its claim before contacting the broker, then
sends an envelope containing `eventId`, `eventSequence`, `executionId`,
`eventKind` and `payload` to the returned topic. Only a durable broker
acknowledgment permits the publisher to call `ack_event` with its worker ID and
lease token. The SQL function cannot independently verify broker acceptance.

A stale token, another worker ID or an expired lease cannot acknowledge an
undelivered event. Successful acknowledgment is idempotent for the same claim.
Unacknowledged events become claimable again after expiry, including after a
publisher/database restart. Worker UUIDs are operational identifiers, not
security principals; the database role is the authorization boundary. A fully
compromised publisher can falsely acknowledge events it legitimately claims.

## Delivery semantics and consumer contract

This is **at-least-once delivery**, not an exactly-once broker claim. A crash after
broker acceptance but before database acknowledgment can publish the same event
again. Consumers must store the event ID in a durable inbox and atomically apply
the event's effect with inbox insertion. A duplicate ID must not reapply the
effect. Trade/position business settlement is already protected by execution
receipts; receiving notifications must never book that trade again.

Multiple publishers can deliver snapshots out of order. A position projection
must compare `eventSequence` per account/security and ignore older snapshots;
a timestamp alone is insufficient. The settlement function serializes each
account, so snapshots for that account acquire increasing event sequences.
There is no global cross-account ordering guarantee and sequence gaps are valid.

No retention/deletion policy is enabled in this candidate. Define retention only
after durable downstream recovery and replay requirements are accepted.

## Validation scope and remaining work

`verify_execution_events.py` exercises real PostgreSQL transaction rollback,
settlement replay, durable snapshots, concurrent leases, restart/reclaim, stale
and unauthorized acknowledgment, successful ack replay and unchanged business
rows during event replay. It simulates the broker-accepted/ack-lost boundary; it
does not run NATS, prove broker persistence, test a real consumer inbox, or claim
deployed event delivery. The future adapter must use authenticated account-scoped
NATS subjects and the common envelope, recover on expiry and expose backlog,
attempt and failed-delivery telemetry.

Observed evidence: [25 November outbox campaign](../evidence/2026-11-25-execution-events.json). These results cover the SQL boundary and simulated acknowledgment-loss scenario only.
