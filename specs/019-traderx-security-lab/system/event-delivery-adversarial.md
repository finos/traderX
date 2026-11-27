# Independent delivery boundary regression

This is a local, synthetic candidate campaign, not an acceptance test of the
deployed application. It complements rather than repeats the
[41-check delivery campaign](event-delivery.md). It uses the existing pinned
reference, SQL migrations, scoped broker and SQL identities, and owned fixture
cleanup. No production adapter or shared fixture is modified.

## Boundaries and controls

- A real settled synthetic trade with price `900719925474099.123` is claimed.
  An expired claim is replaced, and its old worker/token must not acknowledge
  the replacement. The replacement publishes to the TLS broker and its
  acknowledgment updates the outbox.
- Through the consumer login, altered sequence, execution/event identity,
  decimal price and an extra payload key pass wire validation but must fail
  the canonical SQL check with SQLSTATE `22023` and `event unavailable`.
  The inbox and both projections are read independently before and after each
  denial. These inputs are intentionally not tested merely as malformed JSON.
- A valid message commits an inbox and trade projection with the exact decimal.
  An injected failure occurs before sending the broker acknowledgment. A
  real broker redelivery must be a duplicate and leave those rows unchanged.
- Real broker messages with a duplicate nested JSON key or an unexpected
  envelope key must fail at the decoder; a structurally valid but noncanonical
  sequence must fail at the SQL boundary. For each, the campaign inspects the
  authoritative projection and broker pending-ack count before terminating the
  synthetic poison message. Unexpected exceptions, SQLSTATEs and diagnostics
  are failures, not successful denials.
- Seed and synthetic trading tables are fingerprinted after settlement and
  must remain unchanged across all notification operations. Offline tests
  exercise the mutation helpers and ensure unrelated SQL and transport errors
  cannot satisfy a denial check.

The original campaign covers cross-account consumer access, topic
substitution, broker restart, and several other boundaries; those are not
re-proven here. This campaign does not inject a host crash, test graceful worker
shutdown, or establish that a broker acknowledgment represents an application
effect. The acknowledgment-loss fault is deliberately injected, not a real
network or process failure.

## Reproduction

Use CPython 3.14 and the existing dependencies in
`scripts/security-lab/requirements.txt` and the hash-locked
`scripts/security-lab/requirements-delivery.txt`. The pinned generated Git
commit in the state baseline must be available to the existing reference
renderer, even in a shallow checkout. Stop other fixture workloads; the
resource operation lock and preflight apply. On a dedicated native Linux
runner, set `TRADERX_LAB_ISOLATED_LINUX=1` as for the existing fixture.

```bash
python -m unittest discover -s scripts/security-lab -p 'test_event_delivery*.py' -v
python scripts/security-lab/verify_event_delivery_adversarial.py \
  --runtime-dir /absolute/private/runtime \
  --output /absolute/private/new-delivery-adversarial-result.json
```

The verifier writes a new evidence file only after the operation and fixture
contexts have exited successfully. It reports the run commit, source hashes,
platform, dependency versions, image pins, limits and check labels, without
credentials or raw logs. The run uses at most one 256 MiB PostgreSQL fixture
and one 128 MiB non-root broker with loopback-only ports; cleanup removes only
resources with the fixture's unique ownership labels. A forced termination or
Docker failure can still interrupt cleanup. Never use broad pruning.

## Remaining trust and scope

The reference consumer checks the notification against the canonical outbox
in the **same database**; this is not a signature or independent integrity
proof for a consumer using a different database. A compromised authorized
publisher can withhold events or falsely acknowledge its own valid claims,
and bootstrap, database administrators and broker operators retain authority.
No application-consumer cutover, cross-database trust, independent full-state
acceptance, replicated availability or deployed controls are established here.
