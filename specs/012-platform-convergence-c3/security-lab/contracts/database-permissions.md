# Per-service database permissions

Status: implemented and locally verified for SL-T09b and SL-T09c. Inventory verified locally 2026-11-22
against the pinned C3 snapshot and the running synthetic database.

## Observed starting point

Four services receive DATABASE_DBUSER/DATABASE_DBPASS: account-service,
position-service, trade-processor and order-matcher. trade-service calls APIs/NATS
and must not receive a database credential. Live sessions use traderx, which owns
all five public tables and has SUPERUSER, CREATEDB, CREATEROLE and BYPASSRLS.
Kubernetes process restrictions do not change these SQL privileges.

The snapshot's account-service repository uses accounts SELECT/INSERT/UPDATE,
accountusers SELECT/INSERT and accounts_seq nextval. Position repositories read
positions and trades. Trade processor JPA entities persist trades and positions.
Order matcher persists orderbook and currently sets hibernate ddl-auto=update.
Disable runtime DDL (none/validate after compatibility verification); schema changes
must use a separate operator migration path.

## Proposed minimum grants (must pass live compatibility tests)

| Runtime identity | Tables and operations | Sequence |
| --- | --- | --- |
| lab_account | accounts SELECT/INSERT/UPDATE; accountusers SELECT/INSERT | accounts_seq USAGE |
| lab_position | positions/trades SELECT | None |
| lab_trade_processor | trades/positions SELECT/INSERT/UPDATE | None |
| lab_order_matcher | orderbook SELECT/INSERT/UPDATE | None |

All roles: LOGIN, NOSUPERUSER, NOCREATEDB, NOCREATEROLE, NOREPLICATION,
NOBYPASSRLS; no membership in owner/admin roles; no table/schema ownership.
Grant CONNECT and public schema USAGE only. Inventory/revoke PUBLIC schema CREATE
and unrelated grants/default privileges; do not grant blanket ALL or future tables.
Validate exact statements before broadening this matrix. Account/user ownership
checks remain a separate business-authorization requirement.

## Implementation and acceptance

1. Take a private logical checkpoint and record existing ownership, grants and
   defaults without passwords. Acquire the same experiment lock as the console;
   migrate only while no learner experiment is running.
2. Generate distinct credentials outside source/evidence; inject dedicated Secret
   keys into each service. Remove literal runtime credentials from rendered ordinary
   configuration. Keep bootstrap/migration credentials separate from app Pods.
3. Apply idempotent explicit grants, disable matcher runtime DDL and roll out one
   service at a time with readiness and allowed-operation controls. Preserve the
   existing PVC and synthetic records. Admission must reject switching these named
   workloads back to literal/admin credentials or another service's Secret.
4. Verify actual connected role per service, SQL privilege flags, schema ownership,
   and absence of extra membership/grants. Exercise each allowed operation against
   designated synthetic records or rollback-only transactions. Verify unrelated
   table writes, administrative operations and schema DDL fail for the intended SQL
   authorization reason, not a network failure or unavailable database.
5. Run normal account operations, position reads, matching and trade settlement;
   retain independent resulting-state checks. Re-run process/admission verifiers.
6. Rotate one runtime credential, roll its service, verify old credentials fail on
   a new connection and trading continues. Existing pooled sessions are not evidence
   of failed rotation; document their expiry/drain behavior.
7. Add a ninth bounded console experiment for SQL grants. Its checks must use actual
   restricted login identities, not a superuser SET ROLE approximation; no arbitrary
   SQL, user-supplied credentials, table names or targets accepted from the browser.

Rollback must not restore a stale dataset over new trades. Restore only recorded
configuration/grants when safe; preserve phase records and backups for review.
This does not demonstrate user-level row isolation or prevention of malicious writes
within a service's legitimate grants. Those belong to the later canary/runtime work.

Bootstrap retirement is part of this cutover: rotate the source-known administrator
password, keep its replacement in a database-only Secret, verify the old password
fails over TCP, and reject literal bootstrap credential regressions in admission.

## Runtime rotation exercise (SL-T09c)

Target position-service/lab_position only. Serialize with console experiments.
Record original Pod UID, Secret resourceVersion and JDBC backend PIDs/start times;
keep old/new passwords only in a mode-0600 private phase record. Verify old login
works before mutation. Change the PostgreSQL password, prove a new connection with
the retired password is rejected through database service DNS, and prove the new
password succeeds. Record that established JDBC sessions can remain alive after a
password change; do not claim password change revokes existing sessions.

Update the dedicated Secret, restart only position-service, wait for readiness and
verify that the original Pod and original JDBC backend identities are gone and new
role-specific JDBC connections exist. Keep the no-surge rollout policy; brief read
service unavailability is possible. Verify the post-rotation full SQL suite and
normal trading. The console displays this historical rotation proof and checks that
the retired login still fails; it does not initiate rotation on every click.

Interrupted work retains a private phase record and requires --resume. Resume uses
the recorded new credential, never generates a replacement during an in-flight
rotation. A completed exercise is a no-op. Never roll back data or silently reinstate
the retired password to recover. Record any unobserved stage as unknown.
