# Transactional settlement event outbox

Status: the SQL outbox passes 38 PostgreSQL checks; the TLS JetStream publisher
and scoped reference consumer pass 41 additional live checks. Existing application
consumer and deployment integration remain pending. This complements the processor's durable execution receipt.

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
deployed event delivery. The next checkpoint below adds an authenticated adapter and reference projection.
Deployed adapters still require backlog/failure telemetry, supervised recovery
and integration with the existing consumers.

Observed evidence: [25 November outbox campaign](../evidence/2026-11-25-execution-events.json). These results cover the SQL boundary and simulated acknowledgment-loss scenario only.

## Broker and reference projection checkpoint (25 November)

S019-04b2b6 uses a dedicated authenticated JetStream stream with file storage,
explicit account subjects, bounded retention and separate bootstrap, publisher
and consumer identities. The publisher uses the stable event ID as `Nats-Msg-Id`,
requires the expected stream's publish acknowledgment, then acknowledges the SQL
lease. Broker duplicate suppression is an optimization with a finite window.

A reference consumer commits its inbox and read projection atomically before
acknowledging the broker. Its SQL login has a bootstrap-owned account allowlist;
the function checks the envelope against the canonical immutable outbox event.
This extra same-database check detects forged notifications, but is not an
independent cross-database event-signature boundary. It never writes the trading
business tables. Existing application subscribers are not cut over by this
checkpoint. They must adopt the envelope and durable deduplication contract
before any claim of integrated delivery.

The bounded campaign must prove publisher/consumer acknowledgment loss, broker
and database restart, replay beyond the broker duplicate window, stale snapshots,
wrong credentials, TLS trust failure, forbidden publish/management subjects,
SQL consumer account isolation, and rollback of the inbox with a failed effect.
Use one disposable 256 MiB PostgreSQL container and one 128 MiB broker, serialized
with other fixture work; credentials and TLS material stay private. No new
cluster, main merge, or deployed-state change is part of this checkpoint.

Observed result: [41-check delivery campaign](../evidence/2026-11-25-event-delivery.json).
The broker retains accepted events across restart. A new publisher reclaims its
lease and republishes after the one-second test duplicate window has expired,
creating a real extra broker message. A new consumer encounters both broker
redelivery and that duplicate; the database inbox prevents a repeated effect,
including after PostgreSQL restarts. An older position sequence cannot replace a
newer snapshot. A failed projection rolls back its inbox insertion. Concurrent
consumer sessions apply a trade notification once. Business trading tables remain
unchanged throughout notification delivery.

Broker users cannot publish management requests or consume another account's
durable subscription. The database login cannot use a forged envelope, substitute
an account topic, change its allowlist or modify business/projection tables
directly. The reference function validates against the canonical outbox. This
credit belongs to broker permissions and database authorization/integrity checks,
not a WAF or runtime engine. A compromised authorized publisher can still withhold
notifications or acknowledge SQL claims dishonestly; availability and the trust
in bootstrap remain explicit limitations.

The Python adapters preserve PostgreSQL numeric precision with decimal-aware
JSON handling. The live test transports `900719925474099.123` unchanged through
broker and projection; ordinary binary-float encoding would lose precision.
The tested dependencies are pinned with package hashes for CPython 3.14 on macOS
arm64 and Linux amd64. SQL transport is loopback-only in this fixture, not deployed
PostgreSQL TLS. NATS transport verifies the fixture certificate and hostname.

```mermaid
sequenceDiagram
    participant SQL as PostgreSQL settlement + outbox
    participant P as Scoped publisher
    participant N as TLS JetStream
    participant C as Account-scoped consumer
    participant I as Inbox + reference projection
    P->>SQL: Claim pending event with fenced lease
    SQL-->>P: Immutable event ID, sequence and payload
    P->>N: Publish event with stable message ID
    N-->>P: Expected-stream acceptance
    P->>SQL: Acknowledge matching lease
    C->>N: Pull authorized account subscription
    N-->>C: Event (may be a duplicate)
    C->>I: Validate and commit inbox + effect atomically
    I-->>C: Applied, duplicate, or stale
    C->>N: Acknowledge after commit
    Note over P,I: Restart and lost acknowledgments may cause replay; inspect resulting state
```

To reproduce, install `scripts/security-lab/requirements-delivery.txt` with
`pip install --require-hashes -r` in the private lab virtual environment, then run:

```bash
python scripts/security-lab/verify_event_delivery.py \
  --runtime-dir /absolute/private/runtime \
  --output /absolute/private/new-delivery-result.json
```

The shared operation lock must be free; stop the lightweight browser lab first
and restore it afterward. The runner removes only its uniquely labeled broker,
PostgreSQL container and database volume. Private temporary credentials and
certificates are removed on exit. Docker outages or forced process termination
can prevent cleanup; no broad container/volume prune is performed.

Learner exercise: predict whether a broker acknowledgment proves a consumer
effect, then inspect the SQL outcome after each injected loss. Explain why the
inbox remains necessary after the broker's duplicate window expires, and why
this same-database reference check cannot be claimed for an unrelated downstream
system without another trustworthy source of event integrity.

Remaining deployment work includes a supervised publisher/consumer process,
credential provisioning/rotation, consumer envelope adoption in the application,
retention/backlog capacity, poison-event quarantine/recovery and independent
full-stack outcomes. Single-node graceful restart does not prove power-loss or
replicated availability. Existing C3 runtime images and browser behavior remain
unchanged; the checkpoint is not an advertised integrated trading cutover.

Client protocol references: [NATS Python JetStream API](https://nats-io.github.io/nats.py/modules.html)
and [NATS JetStream guide](https://docs.nats.io/learn/jetstream/).
