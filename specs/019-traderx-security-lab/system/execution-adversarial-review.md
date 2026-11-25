# Independent execution adversarial review

Status: sixteen checks passed on 25 November 2026 against the coordinator’s
reservation, settlement and cancellation migrations; one documented residual
authority finding remains. See [recorded evidence](../evidence/2026-11-25-execution-adversarial.json).
This does not mark State 019 deployed or its full security controls accepted.

## Review boundaries

The candidate processor authenticates a dedicated service subject/audience and
accepts only a reservation UUID. SQL settlement derives execution fields from the
reservation, locks the order and account, and atomically updates the trade,
position, order remainder and receipt. Existing HTTP/Java evidence covers token
expiry and forged identities; this independent runner concentrates on SQL state,
replay, conflicting mutations and cancellation ordering.

`verify_execution_adversarial.py` owns one private disposable PostgreSQL fixture,
using the pinned image, 256 MiB, one CPU and no exposed host ports. It queries
business outcomes independently as the fixture administrator. The synthetic
mutations run under the scoped matcher login rather than a database-superuser
attack identity. No production or learner records are touched.

## Findings and integration requirements

### ADV-CANCEL-01 — shared cancellation lock required before cutover

The existing matcher cancellation implementation reads an order and later saves
it under a process-local Java lock. SQL settlement runs in another process and
locks the database row. The Java lock cannot serialize those operations. A stale
save can overwrite fill metadata after settlement commits. This is an integration
blocker, not a finding against a deployed authenticated trading stack: that
cutover has not occurred.

The coordinator's tested `lab_execution.cancel_order(varchar, integer)` does
lock the same database order row, compare the persisted account with the
API-authorized account, preserve an already filled order and preserve fill
metadata when canceling a partially filled remainder. Both ordered races passed
with observed database lock waits; the SQL-level blocker is closed for the
recorded migration hashes. The runner exercises both
orderings using observed database lock waits, not merely simultaneous threads:

- Cancellation holds the row lock first: settlement waits, then is rejected;
  trade, receipt and position remain unchanged.
- Settlement holds it first: cancellation waits, then preserves the fully filled
  order and committed receipt.
- Partial settlement precedes cancellation: only the remainder is canceled;
  the last fill and committed business effects survive.

Until the function exists and these checks pass, the runner emits an `incomplete`
result and exits nonzero. SQL tests alone do not establish that the application
has stopped using the old read/save path; matcher wiring and HTTP validation
remain the coordinator's integration responsibility.

### ADV-WRITER-01 — scoped writer retains residual authority

The matcher database role already has UPDATE permission on OrderBook. It can
therefore overwrite order metadata directly, bypassing a safe cancellation
function. The runner demonstrates a bounded metadata overwrite after settlement
while confirming the trade/position/receipt remain unchanged.

This is documented residual authority for a compromised writer, not proof of an
RCE or of bypassing a WAF. Changing application cancellation fixes the ordinary
race; it does not revoke SQL write authority. Any later claim of protection from
a compromised matcher must either constrain that authority or demonstrate a
separate effective enforcement boundary.

### ADV-RETRY-02 — pending recovery must not depend on a fresh price match

Review of the coordinator's in-progress matcher adapter found that the initial
price-eligibility gate could skip an already persisted pending execution when the
market price changed or no new price arrived after restart. That is a recovery
and liveness concern, not duplicate settlement. Pending execution recovery should
use the stored quantity/price and current authority, separately from eligibility
for creating a new reservation. This was reported to the coordinator for the
scheduler integration; this SQL campaign does not verify that Java correction.

## Other counterexamples

The runner changes one stored reservation-bound field at a time: account,
security, side, accepting subject, issuer, terms and null status. Each denied
settlement must leave trade, receipt and position unchanged. It also checks
cross-order execution-ID reuse, conflicting price/quantity, rollback, and replay
after a discarded successful response plus database restart.

Discarding a response models an unknown delivery outcome; it is not a real TCP
fault injection. Credential expiry is not re-proven by these SQL tests. Snapshot
mutation is not evidence of an exploit in TraderX. A surviving receipt is not
proof that downstream notifications were delivered.

## Reproduction

After the coordinator grants the sequential fixture slot:

```bash
python scripts/security-lab/verify_execution_adversarial.py \
  --runtime-dir /absolute/private/runtime \
  --sql-dir /absolute/reviewed-checkout/specs/019-traderx-security-lab/system/sql \
  --output /absolute/private/adversarial-result.json
```

The optional SQL directory allows an isolated review worktree to verify the
coordinator's reviewed migrations without changing its production files. Evidence
records the hashes of exactly those SQL inputs. No credentials, response tokens
or raw SQL errors are exported. Unexpected outcomes abort instead of recording a
passed security claim.
