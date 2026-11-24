# Background execution delivery contract

Status: PostgreSQL reservation and settlement components tested in an isolated fixture;
Java/HTTP/broker integration is not implemented or deployed. This refines S019-04b2.

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
