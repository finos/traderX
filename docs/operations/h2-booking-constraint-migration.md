# Repair existing H2 booking constraints

Issue #461 affects literal IN-list CHECK constraints in H2 2.4.240 after the
schema-creating connection closes. Fresh generated schemas use equivalent CASE
checks. Existing databases need a migration; do not run initialSchema.sql, which
resets tables. Do not replay historical failed submissions automatically.

1. Stop all writers, including the matcher and trade processor. Back up the H2
   database with `BACKUP TO '/absolute/path/traderx-before-461.zip'` using an admin
   connection (or stop H2 and copy its database files). Verify the backup exists.
2. Query `INFORMATION_SCHEMA.TABLE_CONSTRAINTS` joined to
   `INFORMATION_SCHEMA.CHECK_CONSTRAINTS` on constraint catalog/schema/name. Record
   the four literal IN checks on Trades.Side, Trades.State, OrderBook.Side, and
   OrderBook.Status and their actual constraint names. Do not assume generated names.
3. Add the following replacements. H2 validates existing rows when adding each
   constraint. If any addition fails, stop and investigate; retain all old checks.

```sql
ALTER TABLE Trades ADD CONSTRAINT trades_side_case_461
  CHECK (CASE Side WHEN 'Buy' THEN TRUE WHEN 'Sell' THEN TRUE ELSE Side IS NULL END);
ALTER TABLE Trades ADD CONSTRAINT trades_state_case_461
  CHECK (CASE State WHEN 'New' THEN TRUE WHEN 'Processing' THEN TRUE
    WHEN 'Settled' THEN TRUE WHEN 'Cancelled' THEN TRUE ELSE State IS NULL END);
ALTER TABLE OrderBook ADD CONSTRAINT orderbook_side_case_461
  CHECK (CASE Side WHEN 'Buy' THEN TRUE WHEN 'Sell' THEN TRUE ELSE Side IS NULL END);
ALTER TABLE OrderBook ADD CONSTRAINT orderbook_status_case_461
  CHECK (CASE Status WHEN 'NEW' THEN TRUE WHEN 'PARTIALLY_FILLED' THEN TRUE
    WHEN 'FILLED' THEN TRUE WHEN 'CANCELED' THEN TRUE WHEN 'REJECTED' THEN TRUE
    ELSE Status IS NULL END);
```

4. Only after all four replacements validate, use `ALTER TABLE <table> DROP
   CONSTRAINT <recorded_old_name>` for the four original IN checks. Preserve all
   quantity checks and foreign keys. H2 DDL commits individually: on an interrupted
   migration, inspect installed constraints before continuing; do not blindly rerun.
5. Close the migration connection. Verify valid inserts and invalid side/state
   rejection from a new connection using transactions that are rolled back. Deploy
   the updated processor, resume writers, and verify two sequential buys accumulate
   in REST, live grids, and after reload. Verify a filled limit order in environments
   with a matcher. Preserve existing rows and retain the backup until verified.

Publication is best effort after commit. A logged notification failure means the
booking is already durable; reload REST state and investigate the feed. Never
resubmit the booking just to retry a notification. Crash-safe retries require a
future transactional outbox.
